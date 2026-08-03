import CoreGraphics
import Foundation
import VirtualDisplayBridge

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var status = "Ready"
    @Published private(set) var addresses: [String] = []
    @Published private(set) var statistics = "Waiting for stream"

    private let port: UInt16 = 5900
    private let captureWidth = 1792
    private let captureHeight = 1120
    private let framesPerSecond = 60
    private let averageBitRate = 12_000_000
    private var virtualDisplay: UnsafeMutableRawPointer?
    private var broadcaster: FrameBroadcaster?
    private var captureService: CaptureService?

    func start() {
        guard !isRunning else { return }

        guard CGPreflightScreenCaptureAccess() else {
            status = "Requesting Screen Recording permission…"
            if CGRequestScreenCaptureAccess() {
                status = "Permission granted. Click again to create the display."
            } else {
                status = "Enable DeskWeave in Privacy & Security → Screen Recording."
            }
            return
        }

        status = "Creating virtual display…"

        guard SSVVirtualDisplayAPIAvailable() else {
            status = "This macOS version does not expose the required virtual display API."
            return
        }

        guard let display = SSVCreateVirtualDisplay(
            UInt32(captureWidth),
            UInt32(captureHeight),
            60
        ) else {
            status = "macOS refused to create the virtual display."
            return
        }
        virtualDisplay = display
        let displayID = SSVVirtualDisplayID(display)

        let broadcaster = FrameBroadcaster { [weak self] message in
            self?.status = message
        }
        do {
            try broadcaster.start(port: port)
        } catch {
            SSVReleaseVirtualDisplay(display)
            virtualDisplay = nil
            status = "Could not open port \(port): \(error.localizedDescription)"
            return
        }
        self.broadcaster = broadcaster

        let captureService = CaptureService(
            broadcaster: broadcaster
        ) { [weak self] fps, kbps in
            self?.statistics = "\(fps) fps • \(kbps) kbit/s"
        }
        self.captureService = captureService
        addresses = NetworkAddress.localIPv4Addresses(port: port)
        isRunning = true
        status = "Display created. Starting capture…"

        Task {
            do {
                // WindowServer may need a moment to publish a newly-created display.
                try await Task.sleep(nanoseconds: 700_000_000)
                try await captureService.start(
                    displayID: displayID,
                    width: captureWidth,
                    height: captureHeight,
                    framesPerSecond: framesPerSecond,
                    averageBitRate: averageBitRate
                )
                status = "Waiting for tablet"
            } catch {
                let failure = "Capture failed: \(error.localizedDescription)"
                await stop()
                status = failure
            }
        }
    }

    func stop() async {
        guard isRunning || virtualDisplay != nil else { return }
        status = "Stopping…"
        await captureService?.stop()
        captureService = nil
        broadcaster?.stop()
        broadcaster = nil

        if let virtualDisplay {
            SSVReleaseVirtualDisplay(virtualDisplay)
            self.virtualDisplay = nil
        }

        isRunning = false
        addresses = []
        statistics = "Waiting for stream"
        status = "Stopped"
    }
}
