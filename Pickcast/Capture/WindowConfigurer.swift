import SwiftUI
import AppKit

// Disables native window tabbing so macOS never tries to merge our window
// into a tab group behind our back.
struct TabbingDisabler: NSViewRepresentable {
    func makeNSView(context: Context) -> DisablerView { DisablerView() }
    func updateNSView(_ nsView: DisablerView, context: Context) {}

    final class DisablerView: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            window?.tabbingMode = .disallowed
        }
    }
}
