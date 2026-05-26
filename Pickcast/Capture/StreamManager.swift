import Foundation
import ScreenCaptureKit
import CoreMedia

@MainActor
final class StreamManager {
    static let shared = StreamManager()

    private struct Entry {
        var stream: SCStream
        var output: StreamOutput
        var subscriberCount: Int = 0
    }

    private var entries: [CGWindowID: Entry] = [:]

    // Attach a display layer to a window's stream.
    // If the stream is already running, just redirects frames to the new callback.
    func subscribe(
        to window: SCWindow,
        onFrame: @escaping (CMSampleBuffer) -> Void,
        onStop:  @escaping @MainActor () -> Void
    ) async throws {
        if entries[window.windowID] != nil {
            entries[window.windowID]!.output.onFrame = onFrame
            entries[window.windowID]!.output.onStop  = onStop
            entries[window.windowID]!.subscriberCount += 1
            return
        }

        let filter = SCContentFilter(desktopIndependentWindow: window)
        let config = SCStreamConfiguration()
        let frame  = window.frame
        let scale: CGFloat = 2.0
        config.width  = min(3840, max(320, Int(frame.width  * scale)))
        config.height = min(2160, max(200, Int(frame.height * scale)))
        config.minimumFrameInterval = CMTime(value: 1, timescale: 30)
        config.queueDepth = 3

        let output = StreamOutput(onFrame: onFrame, onStop: onStop)
        let stream = SCStream(filter: filter, configuration: config, delegate: output)
        try stream.addStreamOutput(
            output, type: .screen,
            sampleHandlerQueue: .global(qos: .userInteractive)
        )
        try await stream.startCapture()
        entries[window.windowID] = Entry(stream: stream, output: output, subscriberCount: 1)
    }

    // Detach one subscriber. If count reaches zero, stop the stream after a short
    // delay so that a swap (unsubscribe A → subscribe B within the same render
    // pass) doesn't cause an unnecessary stop/restart.
    func unsubscribe(windowID: CGWindowID) {
        guard entries[windowID] != nil else { return }
        entries[windowID]!.subscriberCount -= 1
        guard entries[windowID]!.subscriberCount <= 0 else { return }

        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000) // 300 ms
            guard let self else { return }
            if (self.entries[windowID]?.subscriberCount ?? 0) <= 0 {
                let entry = self.entries.removeValue(forKey: windowID)
                if let entry { try? await entry.stream.stopCapture() }
            }
        }
    }

    func throttleCapture(windowID: CGWindowID) {
        guard let entry = entries[windowID] else { return }
        let config = SCStreamConfiguration()
        config.minimumFrameInterval = CMTime(value: 1, timescale: 5)
        Task { try? await entry.stream.updateConfiguration(config) }
    }

    func unthrottleCapture(windowID: CGWindowID) {
        guard let entry = entries[windowID] else { return }
        let config = SCStreamConfiguration()
        config.minimumFrameInterval = CMTime(value: 1, timescale: 30)
        Task { try? await entry.stream.updateConfiguration(config) }
    }
}

private final class StreamOutput: NSObject, SCStreamOutput, SCStreamDelegate {
    var onFrame: (CMSampleBuffer) -> Void
    var onStop:  @MainActor () -> Void

    init(
        onFrame: @escaping (CMSampleBuffer) -> Void,
        onStop:  @escaping @MainActor () -> Void
    ) {
        self.onFrame = onFrame
        self.onStop  = onStop
    }

    func stream(
        _ stream: SCStream,
        didOutputSampleBuffer buffer: CMSampleBuffer,
        of type: SCStreamOutputType
    ) {
        guard type == .screen, buffer.isValid else { return }
        onFrame(buffer)
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        Task { @MainActor [weak self] in self?.onStop() }
    }
}
