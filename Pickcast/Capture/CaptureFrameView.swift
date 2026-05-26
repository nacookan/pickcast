import SwiftUI
import AVFoundation
import ScreenCaptureKit

struct CaptureFrameView: NSViewRepresentable {
    let window: SCWindow
    var onWindowClosed: @MainActor () -> Void

    func makeNSView(context: Context) -> CaptureNSView {
        let view = CaptureNSView()
        view.wantsLayer = true
        return view
    }

    func updateNSView(_ nsView: CaptureNSView, context: Context) {
        nsView.startCapture(window: window, onWindowClosed: onWindowClosed)
    }

    static func dismantleNSView(_ nsView: CaptureNSView, coordinator: ()) {
        nsView.stopCapture()
    }
}

final class CaptureNSView: NSView {
    private static let bgColor = NSColor(calibratedWhite: 0.18, alpha: 1).cgColor

    private var displayLayer: AVSampleBufferDisplayLayer?
    private var currentWindowID: CGWindowID?

    override func layout() {
        super.layout()
        displayLayer?.frame = bounds
    }

    func startCapture(window: SCWindow, onWindowClosed: @escaping @MainActor () -> Void) {
        guard window.windowID != currentWindowID else { return }

        // Detach from the previous stream without stopping it immediately —
        // the 300 ms grace period in StreamManager lets a concurrent swap
        // re-subscribe before the stream dies.
        if let oldID = currentWindowID {
            StreamManager.shared.unsubscribe(windowID: oldID)
        }
        currentWindowID = window.windowID

        wantsLayer = true
        layer?.backgroundColor = Self.bgColor

        displayLayer?.removeFromSuperlayer()
        let layer = AVSampleBufferDisplayLayer()
        layer.frame        = bounds
        layer.videoGravity = .resizeAspect
        layer.backgroundColor = Self.bgColor
        self.layer?.addSublayer(layer)
        displayLayer = layer

        Task { @MainActor in
            try? await StreamManager.shared.subscribe(
                to: window,
                onFrame: { [weak layer] buffer in
                    guard let layer else { return }
                    if layer.status == .failed { layer.flush() }
                    layer.enqueue(buffer)
                },
                onStop: onWindowClosed
            )
        }
    }

    func stopCapture() {
        if let id = currentWindowID {
            StreamManager.shared.unsubscribe(windowID: id)
        }
        currentWindowID = nil
        displayLayer?.removeFromSuperlayer()
        displayLayer = nil
    }
}
