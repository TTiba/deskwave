import CoreMedia
import CoreVideo
import Foundation
import VideoToolbox

final class H264Encoder {
    typealias EncodedFrameHandler = (
        _ data: Data,
        _ presentationTimeMicroseconds: UInt64,
        _ isKeyFrame: Bool
    ) -> Void
    typealias ConfigurationHandler = (H264StreamConfiguration) -> Void

    private let width: Int32
    private let height: Int32
    private let framesPerSecond: Int32
    private let configurationHandler: ConfigurationHandler
    private let encodedFrameHandler: EncodedFrameHandler

    private var session: VTCompressionSession?
    private var lastConfiguration: H264StreamConfiguration?
    private var nalUnitHeaderLength: Int = 4
    private var fallbackFrameNumber: Int64 = 0

    init(
        width: Int,
        height: Int,
        framesPerSecond: Int,
        averageBitRate: Int,
        configurationHandler: @escaping ConfigurationHandler,
        encodedFrameHandler: @escaping EncodedFrameHandler
    ) throws {
        self.width = Int32(width)
        self.height = Int32(height)
        self.framesPerSecond = Int32(framesPerSecond)
        self.configurationHandler = configurationHandler
        self.encodedFrameHandler = encodedFrameHandler

        let encoderSpecification = [
            kVTVideoEncoderSpecification_RequireHardwareAcceleratedVideoEncoder: true
        ] as CFDictionary

        var createdSession: VTCompressionSession?
        let status = VTCompressionSessionCreate(
            allocator: kCFAllocatorDefault,
            width: Int32(width),
            height: Int32(height),
            codecType: kCMVideoCodecType_H264,
            encoderSpecification: encoderSpecification,
            imageBufferAttributes: nil,
            compressedDataAllocator: nil,
            outputCallback: h264CompressionOutputCallback,
            refcon: Unmanaged.passUnretained(self).toOpaque(),
            compressionSessionOut: &createdSession
        )
        guard status == noErr, let createdSession else {
            throw EncoderError.cannotCreate(status)
        }
        session = createdSession

        let properties = [
            kVTCompressionPropertyKey_RealTime: true,
            kVTCompressionPropertyKey_AllowFrameReordering: false,
            kVTCompressionPropertyKey_ProfileLevel: kVTProfileLevel_H264_Main_4_2,
            kVTCompressionPropertyKey_AverageBitRate: averageBitRate,
            kVTCompressionPropertyKey_DataRateLimits: [
                averageBitRate * 2 / 8,
                1
            ],
            kVTCompressionPropertyKey_ExpectedFrameRate: framesPerSecond,
            kVTCompressionPropertyKey_MaxKeyFrameInterval: framesPerSecond,
            kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration: 1,
            kVTCompressionPropertyKey_PrioritizeEncodingSpeedOverQuality: false
        ] as CFDictionary

        let propertyStatus = VTSessionSetProperties(
            createdSession,
            propertyDictionary: properties
        )
        guard propertyStatus == noErr else {
            VTCompressionSessionInvalidate(createdSession)
            session = nil
            throw EncoderError.cannotConfigure(propertyStatus)
        }

        let prepareStatus = VTCompressionSessionPrepareToEncodeFrames(createdSession)
        guard prepareStatus == noErr else {
            VTCompressionSessionInvalidate(createdSession)
            session = nil
            throw EncoderError.cannotPrepare(prepareStatus)
        }
    }

    deinit {
        invalidate()
    }

    func encode(_ pixelBuffer: CVPixelBuffer, presentationTimeStamp: CMTime) throws {
        guard let session else {
            throw EncoderError.invalidSession
        }

        let timeStamp: CMTime
        if presentationTimeStamp.isValid, !presentationTimeStamp.isIndefinite {
            timeStamp = presentationTimeStamp
        } else {
            timeStamp = CMTime(
                value: fallbackFrameNumber,
                timescale: framesPerSecond
            )
        }
        fallbackFrameNumber += 1

        var infoFlags = VTEncodeInfoFlags()
        let status = VTCompressionSessionEncodeFrame(
            session,
            imageBuffer: pixelBuffer,
            presentationTimeStamp: timeStamp,
            duration: CMTime(value: 1, timescale: framesPerSecond),
            frameProperties: nil,
            sourceFrameRefcon: nil,
            infoFlagsOut: &infoFlags
        )
        guard status == noErr else {
            throw EncoderError.cannotEncode(status)
        }
    }

    func invalidate() {
        guard let session else { return }
        VTCompressionSessionCompleteFrames(
            session,
            untilPresentationTimeStamp: .invalid
        )
        VTCompressionSessionInvalidate(session)
        self.session = nil
    }

    fileprivate func handleEncodedSample(
        status: OSStatus,
        infoFlags: VTEncodeInfoFlags,
        sampleBuffer: CMSampleBuffer?
    ) {
        guard status == noErr,
              !infoFlags.contains(.frameDropped),
              let sampleBuffer,
              sampleBuffer.isValid,
              CMSampleBufferDataIsReady(sampleBuffer),
              let blockBuffer = sampleBuffer.dataBuffer else {
            return
        }

        let isKeyFrame = Self.isKeyFrame(sampleBuffer)
        if isKeyFrame {
            publishConfigurationIfNeeded(from: sampleBuffer)
        }

        let avccLength = CMBlockBufferGetDataLength(blockBuffer)
        guard avccLength > 0 else { return }

        var avcc = Data(count: avccLength)
        let copyStatus = avcc.withUnsafeMutableBytes { rawBuffer -> OSStatus in
            guard let destination = rawBuffer.baseAddress else {
                return kCMBlockBufferBadCustomBlockSourceErr
            }
            return CMBlockBufferCopyDataBytes(
                blockBuffer,
                atOffset: 0,
                dataLength: avccLength,
                destination: destination
            )
        }
        guard copyStatus == kCMBlockBufferNoErr,
              let annexB = Self.convertAVCCToAnnexB(
                avcc,
                nalUnitHeaderLength: nalUnitHeaderLength
              ) else {
            return
        }

        let presentationTime = sampleBuffer.presentationTimeStamp
        let microseconds: UInt64
        if presentationTime.isValid, !presentationTime.isIndefinite {
            let converted = CMTimeConvertScale(
                presentationTime,
                timescale: 1_000_000,
                method: .default
            )
            microseconds = UInt64(max(0, converted.value))
        } else {
            microseconds = 0
        }

        encodedFrameHandler(annexB, microseconds, isKeyFrame)
    }

    private func publishConfigurationIfNeeded(from sampleBuffer: CMSampleBuffer) {
        guard let formatDescription = sampleBuffer.formatDescription else { return }

        var sequencePointer: UnsafePointer<UInt8>?
        var sequenceSize = 0
        var parameterSetCount = 0
        var headerLength: Int32 = 0
        let sequenceStatus = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(
            formatDescription,
            parameterSetIndex: 0,
            parameterSetPointerOut: &sequencePointer,
            parameterSetSizeOut: &sequenceSize,
            parameterSetCountOut: &parameterSetCount,
            nalUnitHeaderLengthOut: &headerLength
        )

        var picturePointer: UnsafePointer<UInt8>?
        var pictureSize = 0
        let pictureStatus = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(
            formatDescription,
            parameterSetIndex: 1,
            parameterSetPointerOut: &picturePointer,
            parameterSetSizeOut: &pictureSize,
            parameterSetCountOut: nil,
            nalUnitHeaderLengthOut: nil
        )

        guard sequenceStatus == noErr,
              pictureStatus == noErr,
              let sequencePointer,
              let picturePointer,
              sequenceSize <= Int(UInt16.max),
              pictureSize <= Int(UInt16.max) else {
            return
        }

        nalUnitHeaderLength = Int(headerLength)
        let configuration = H264StreamConfiguration(
            width: UInt16(width),
            height: UInt16(height),
            framesPerSecond: UInt16(framesPerSecond),
            sequenceParameterSet: Data(bytes: sequencePointer, count: sequenceSize),
            pictureParameterSet: Data(bytes: picturePointer, count: pictureSize)
        )
        guard configuration != lastConfiguration else { return }

        lastConfiguration = configuration
        configurationHandler(configuration)
    }

    private static func isKeyFrame(_ sampleBuffer: CMSampleBuffer) -> Bool {
        guard let attachments = CMSampleBufferGetSampleAttachmentsArray(
            sampleBuffer,
            createIfNecessary: false
        ) as? [[CFString: Any]],
              let first = attachments.first else {
            return true
        }
        return !(first[kCMSampleAttachmentKey_NotSync] as? Bool ?? false)
    }

    private static func convertAVCCToAnnexB(
        _ data: Data,
        nalUnitHeaderLength: Int
    ) -> Data? {
        guard (1...4).contains(nalUnitHeaderLength) else { return nil }

        var output = Data(capacity: data.count + 32)
        var offset = 0
        while offset + nalUnitHeaderLength <= data.count {
            var nalLength = 0
            for byte in data[offset..<(offset + nalUnitHeaderLength)] {
                nalLength = (nalLength << 8) | Int(byte)
            }
            offset += nalUnitHeaderLength

            guard nalLength > 0, offset + nalLength <= data.count else {
                return nil
            }

            output.append(contentsOf: [0, 0, 0, 1])
            output.append(data[offset..<(offset + nalLength)])
            offset += nalLength
        }

        return offset == data.count ? output : nil
    }

    enum EncoderError: LocalizedError {
        case cannotCreate(OSStatus)
        case cannotConfigure(OSStatus)
        case cannotPrepare(OSStatus)
        case cannotEncode(OSStatus)
        case invalidSession

        var errorDescription: String? {
            switch self {
            case .cannotCreate(let status):
                return "Could not create the H.264 encoder (\(status))."
            case .cannotConfigure(let status):
                return "Could not configure the H.264 encoder (\(status))."
            case .cannotPrepare(let status):
                return "Could not prepare the H.264 encoder (\(status))."
            case .cannotEncode(let status):
                return "Failed to encode an H.264 frame (\(status))."
            case .invalidSession:
                return "The H.264 session has already ended."
            }
        }
    }
}

private let h264CompressionOutputCallback: VTCompressionOutputCallback = {
    refcon,
    _,
    status,
    infoFlags,
    sampleBuffer in
    guard let refcon else { return }
    let encoder = Unmanaged<H264Encoder>.fromOpaque(refcon).takeUnretainedValue()
    encoder.handleEncodedSample(
        status: status,
        infoFlags: infoFlags,
        sampleBuffer: sampleBuffer
    )
}
