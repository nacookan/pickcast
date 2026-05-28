import Foundation
import ScreenCaptureKit
import CoreMedia
import CoreGraphics

@MainActor
final class StreamManager {
    static let shared = StreamManager()

    private struct Entry {
        var stream: SCStream
        var output: StreamOutput
        var subscriberCount: Int = 0
        var boundsSize: CGSize  // kCGWindowBounds size, used only to detect changes
    }

    private var entries: [CGWindowID: Entry] = [:]
    private var resizeTimer: Timer?

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

        // Get accurate pixel dimensions (shadow-free) and bounds size before starting
        // the stream, so the initial config is correct without needing updateConfiguration.
        let windowID = window.windowID
        let (pixelSize, boundsSize) = await Task.detached(priority: .utility) {
            let pixel = actualPixelSize(for: windowID)
            let bounds = cgWindowBoundsSize(for: windowID)
            return (pixel, bounds)
        }.value

        let config = pixelSize.map { makeConfigFromPixels($0) } ?? makeConfig(for: window.frame.size)

        let output = StreamOutput(onFrame: onFrame, onStop: onStop)
        let stream = SCStream(filter: filter, configuration: config, delegate: output)
        try stream.addStreamOutput(
            output, type: .screen,
            sampleHandlerQueue: .global(qos: .userInteractive)
        )
        try await stream.startCapture()
        entries[windowID] = Entry(stream: stream, output: output, subscriberCount: 1,
                                  boundsSize: boundsSize ?? window.frame.size)
        startResizeTimerIfNeeded()
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
                self.stopResizeTimerIfNeeded()
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

    private func makeConfig(for logicalSize: CGSize) -> SCStreamConfiguration {
        let scale: CGFloat = 2.0
        return makeConfigFromPixels(CGSize(width: logicalSize.width * scale,
                                          height: logicalSize.height * scale))
    }

    private func makeConfigFromPixels(_ pixelSize: CGSize) -> SCStreamConfiguration {
        let config = SCStreamConfiguration()
        config.width  = max(2, Int(pixelSize.width))
        config.height = max(2, Int(pixelSize.height))
        config.minimumFrameInterval = CMTime(value: 1, timescale: 30)
        config.queueDepth = 3
        return config
    }

    private func startResizeTimerIfNeeded() {
        guard resizeTimer == nil else { return }
        resizeTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            self?.checkWindowSizes()
        }
    }

    private func stopResizeTimerIfNeeded() {
        guard entries.isEmpty else { return }
        resizeTimer?.invalidate()
        resizeTimer = nil
    }

    private func checkWindowSizes() {
        guard !entries.isEmpty,
              let windowInfoList = CGWindowListCopyWindowInfo([], kCGNullWindowID) as? [[String: Any]]
        else { return }

        for info in windowInfoList {
            guard let num = info[kCGWindowNumber as String] as? Int, num >= 0,
                  let boundsDict = info[kCGWindowBounds as String] as? [String: Any],
                  let width = boundsDict["Width"] as? CGFloat,
                  let height = boundsDict["Height"] as? CGFloat,
                  width > 0, height > 0
            else { continue }

            let windowID = CGWindowID(num)
            guard var entry = entries[windowID],
                  abs(width - entry.boundsSize.width) > 2 || abs(height - entry.boundsSize.height) > 2
            else { continue }

            entry.boundsSize = CGSize(width: width, height: height)
            entries[windowID] = entry

            let stream = entry.stream
            Task(priority: .utility) { [weak self] in
                guard let pixelSize = actualPixelSize(for: windowID), pixelSize.width > 0 else { return }
                await MainActor.run {
                    guard let self, self.entries[windowID] != nil else { return }
                    let config = self.makeConfigFromPixels(pixelSize)
                    Task { try? await stream.updateConfiguration(config) }
                }
            }
        }
    }
}

// Returns pixel dimensions of the window content, excluding shadow.
private func actualPixelSize(for windowID: CGWindowID) -> CGSize? {
    guard let image = CGWindowListCreateImage(
        .null, .optionIncludingWindow, windowID, [.boundsIgnoreFraming, .bestResolution]
    ) else { return nil }
    return CGSize(width: CGFloat(image.width), height: CGFloat(image.height))
}

// Returns the window bounds size from CGWindowList (shadow-inclusive, for resize detection).
private func cgWindowBoundsSize(for windowID: CGWindowID) -> CGSize? {
    guard let list = CGWindowListCopyWindowInfo([], kCGNullWindowID) as? [[String: Any]] else { return nil }
    return list
        .first { ($0[kCGWindowNumber as String] as? Int) == Int(windowID) }
        .flatMap { info -> CGSize? in
            guard let b = info[kCGWindowBounds as String] as? [String: Any],
                  let w = b["Width"] as? CGFloat, let h = b["Height"] as? CGFloat
            else { return nil }
            return CGSize(width: w, height: h)
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
