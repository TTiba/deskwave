import CoreMedia
import Foundation
import ScreenCaptureKit

final class CaptureService: NSObject, SCStreamOutput, SCStreamDelegate {
    typealias StatisticsHandler = (_ framesPerSecond: Int, _ kilobitsPerSecond: Int) -> Void

    private let broadcaster: FrameBroadcaster
    private let outputQueue = DispatchQueue(
        label: "second-screen.capture",
        qos: .userInteractive
    )
    private let statisticsHandler: StatisticsHandler

    private var stream: SCStream?
    private var encoder: H264Encoder?
    private var framesSinceReport = 0
    private var bytesSinceReport = 0
    private var lastReport = Date()

    init(
        broadcaster: FrameBroadcaster,
        statisticsHandler: @escaping StatisticsHandler
    ) {
        self.broadcaster = broadcaster
        self.statisticsHandler = statisticsHandler
        super.init()
    }

    func start(
        displayID: CGDirectDisplayID,
        width: Int,
        height: Int,
        framesPerSecond: Int,
        averageBitRate: Int
    ) async throws {
        var selectedDisplay: SCDisplay?
        for attempt in 0..<10 {
            let content = try await SCShareableContent.excludingDesktopWindows(
                false,
                onScreenWindowsOnly: false
            )
            selectedDisplay = content.displays.first(where: { $0.displayID == displayID })
            if selectedDisplay != nil {
                break
            }
            if attempt < 9 {
                try await Task.sleep(nanoseconds: 300_000_000)
            }
        }

        guard let display = selectedDisplay else {
            throw CaptureError.displayNotFound
        }

        let encoder = try H264Encoder(
            width: width,
            height: height,
            framesPerSecond: framesPerSecond,
            averageBitRate: averageBitRate,
            configurationHandler: { [weak broadcaster] configuration in
                broadcaster?.publish(configuration: configuration)
            },
            encodedFrameHandler: { [weak self, weak broadcaster] data, time, keyFrame in
                broadcaster?.publish(
                    frame: data,
                    presentationTimeMicroseconds: time,
                    isKeyFrame: keyFrame
                )
                self?.updateStatistics(frameBytes: data.count)
            }
        )
        self.encoder = encoder

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let configuration = SCStreamConfiguration()
        configuration.width = width
        configuration.height = height
        configuration.minimumFrameInterval = CMTime(
            value: 1,
            timescale: CMTimeScale(framesPerSecond)
        )
        configuration.queueDepth = 3
        configuration.pixelFormat = kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        configuration.showsCursor = true
        configuration.capturesAudio = false
        configuration.shouldBeOpaque = true

        let stream = SCStream(
            filter: filter,
            configuration: configuration,
            delegate: self
        )
        try stream.addStreamOutput(
            self,
            type: .screen,
            sampleHandlerQueue: outputQueue
        )
        try await stream.startCapture()
        self.stream = stream
    }

    func stop() async {
        if let stream {
            try? await stream.stopCapture()
            self.stream = nil
        }
        encoder?.invalidate()
        encoder = nil
    }

    func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of outputType: SCStreamOutputType
    ) {
        guard outputType == .screen,
              sampleBuffer.isValid,
              let pixelBuffer = sampleBuffer.imageBuffer else {
            return
        }

        do {
            try encoder?.encode(
                pixelBuffer,
                presentationTimeStamp: sampleBuffer.presentationTimeStamp
            )
        } catch {
            NSLog("Second Screen H.264 encode error: \(error.localizedDescription)")
        }
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        NSLog("Second Screen capture stopped: \(error.localizedDescription)")
    }

    private func updateStatistics(frameBytes: Int) {
        framesSinceReport += 1
        bytesSinceReport += frameBytes
        let elapsed = Date().timeIntervalSince(lastReport)

        guard elapsed >= 1 else { return }

        let fps = Int((Double(framesSinceReport) / elapsed).rounded())
        let kbps = Int((Double(bytesSinceReport * 8) / elapsed / 1_000).rounded())
        framesSinceReport = 0
        bytesSinceReport = 0
        lastReport = Date()

        DispatchQueue.main.async {
            self.statisticsHandler(fps, kbps)
        }
    }

    enum CaptureError: LocalizedError {
        case displayNotFound

        var errorDescription: String? {
            "The virtual display was created but is not available for capture yet."
        }
    }
}
