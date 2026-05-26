import SwiftUI
import AppKit

// MARK: - Layout

struct PaneLayoutView: View {
    @ObservedObject var tab: TabLayout

    private let minSide:   CGFloat = 140
    private let minMain:   CGFloat = 280
    private let minBottom: CGFloat = 100
    private let divW:      CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                // ── top row ──────────────────────────────────────────
                HStack(spacing: 0) {

                    if tab.showLeft {
                        PaneView(tab: tab, role: .left)
                            .frame(width: tab.leftWidth)
                        ResizeDivider(axis: .horizontal) { delta in
                            let avail = geo.size.width
                                - minMain
                                - (tab.showRight ? tab.rightWidth + divW : 0)
                                - divW
                            tab.leftWidth = clamp(tab.leftWidth + delta, lo: minSide, hi: avail)
                        }
                    }

                    PaneView(tab: tab, role: .main)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    if tab.showRight {
                        ResizeDivider(axis: .horizontal) { delta in
                            let avail = geo.size.width
                                - minMain
                                - (tab.showLeft ? tab.leftWidth + divW : 0)
                                - divW
                            tab.rightWidth = clamp(tab.rightWidth - delta, lo: minSide, hi: avail)
                        }
                        PaneView(tab: tab, role: .right)
                            .frame(width: tab.rightWidth)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // ── bottom pane ──────────────────────────────────────
                if tab.showBottom {
                    ResizeDivider(axis: .vertical) { delta in
                        let avail = geo.size.height - minMain - divW
                        tab.bottomHeight = clamp(tab.bottomHeight - delta, lo: minBottom, hi: avail)
                    }
                    PaneView(tab: tab, role: .bottom)
                        .frame(height: tab.bottomHeight)
                }
            }
        }
    }

    private func clamp(_ v: CGFloat, lo: CGFloat, hi: CGFloat) -> CGFloat {
        max(lo, min(hi, v))
    }
}

// MARK: - Divider

struct ResizeDivider: View {
    enum Axis { case horizontal, vertical }

    let axis: Axis
    let onDrag: (CGFloat) -> Void

    @State private var lastOffset: CGFloat = 0

    var body: some View {
        ResizeCursorZone(axis: axis)
            .frame(
                width:  axis == .horizontal ? 6 : nil,
                height: axis == .vertical   ? 6 : nil
            )
            .overlay(
                Rectangle()
                    .fill(Color(nsColor: .separatorColor).opacity(0.7))
                    .frame(
                        width:  axis == .horizontal ? 1 : nil,
                        height: axis == .vertical   ? 1 : nil
                    )
                    .allowsHitTesting(false)
            )
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .global)
                    .onChanged { value in
                        let offset = axis == .horizontal
                            ? value.translation.width
                            : value.translation.height
                        onDrag(offset - lastOffset)
                        lastOffset = offset
                    }
                    .onEnded { _ in lastOffset = 0 }
            )
    }
}

private struct ResizeCursorZone: NSViewRepresentable {
    let axis: ResizeDivider.Axis

    func makeNSView(context: Context) -> CursorView { CursorView(axis: axis) }
    func updateNSView(_ nsView: CursorView, context: Context) {}

    class CursorView: NSView {
        let axis: ResizeDivider.Axis
        init(axis: ResizeDivider.Axis) {
            self.axis = axis
            super.init(frame: .zero)
        }
        required init?(coder: NSCoder) { fatalError() }
        override func resetCursorRects() {
            addCursorRect(bounds, cursor: axis == .horizontal ? .resizeLeftRight : .resizeUpDown)
        }
    }
}
