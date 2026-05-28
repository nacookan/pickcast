import SwiftUI
import ScreenCaptureKit
import UniformTypeIdentifiers

// MARK: - PaneRole

enum PaneRole: String, Codable, Transferable {
    case main, left, right, bottom

    var label: String {
        switch self {
        case .main:   "Main"
        case .left:   "Left"
        case .right:  "Right"
        case .bottom: "Bottom"
        }
    }

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .paneRole)
    }
}

extension UTType {
    static let paneRole = UTType(exportedAs: "com.nacookan.pickcast.panerole")
}

// MARK: - PaneView

struct PaneView: View {
    @ObservedObject var tab: TabLayout
    let role: PaneRole

    @State private var showPicker  = false
    @State private var isHovering  = false
    @State private var isDropTarget = false

    private var window: SCWindow? { tab.window(for: role) }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if let window {
                CaptureFrameView(window: window) {
                    tab.setWindow(nil, for: role)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if isHovering {
                    closeButton
                        .transition(.opacity)
                }
            } else {
                emptyState
            }

            // Drop target highlight
            if isDropTarget {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.accentColor, lineWidth: 3)
                    .allowsHitTesting(false)
            }
        }
        .onHover { isHovering = $0 }
        .draggable(role) {
            // drag preview
            Label(role.label, systemImage: "rectangle.on.rectangle")
                .padding(8)
                .background(.regularMaterial)
                .cornerRadius(8)
        }
        .dropDestination(for: PaneRole.self) { roles, _ in
            guard let source = roles.first, source != role else { return false }
            tab.swapWindows(source: source, dest: role)
            return true
        } isTargeted: {
            isDropTarget = $0
        }
        .sheet(isPresented: $showPicker) {
            WindowPickerView { selected in
                tab.setWindow(selected, for: role)
                showPicker = false
            }
        }
    }

    private var closeButton: some View {
        Button {
            withAnimation { tab.setWindow(nil, for: role) }
        } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 20))
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, Color(white: 0, opacity: 0.55))
        }
        .buttonStyle(.plain)
        .padding(8)
    }

    private var emptyState: some View {
        Button { showPicker = true } label: {
            VStack(spacing: 10) {
                Image(systemName: "plus.rectangle.on.rectangle")
                    .font(.system(size: 34))
                Text("Add \(role.label) Window")
                    .font(.callout)
            }
            .foregroundStyle(Color(white: 0.65))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
        .background(Color(nsColor: NSColor(calibratedWhite: 0.18, alpha: 1)))
    }
}
