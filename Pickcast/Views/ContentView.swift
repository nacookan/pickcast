import SwiftUI
import ScreenCaptureKit
import Combine

// Holds all 5 tabs and forwards any tab's published changes up to ContentView.
final class TabStore: ObservableObject {
    let tabs: [TabLayout] = (1...5).map { TabLayout(number: $0) }
    @Published var selectedIndex = 0

    private var cancellables: Set<AnyCancellable> = []

    init() {
        tabs.forEach { tab in
            tab.objectWillChange
                .receive(on: RunLoop.main)
                .sink { [weak self] in self?.objectWillChange.send() }
                .store(in: &cancellables)
        }
    }

    var current: TabLayout { tabs[selectedIndex] }
}

struct ContentView: View {
    @StateObject private var store = TabStore()
    @State private var permissionGranted: Bool?

    var body: some View {
        Group {
            switch permissionGranted {
            case .none:
                ProgressView("Checking permissions…")
                    .frame(width: 300, height: 200)
            case .some(true):
                // All 5 tabs stay in the view tree at all times so their
                // capture streams are never torn down on a tab switch.
                ZStack {
                    ForEach(0..<5, id: \.self) { i in
                        PaneLayoutView(tab: store.tabs[i])
                            .opacity(i == store.selectedIndex ? 1 : 0)
                            .allowsHitTesting(i == store.selectedIndex)
                            .zIndex(i == store.selectedIndex ? 1 : 0)
                    }
                }
            case .some(false):
                PermissionView { Task { await checkPermission() } }
            }
        }
        .frame(minWidth: 800, minHeight: 560)
        .background(TabbingDisabler())
        .task { await checkPermission() }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("", selection: $store.selectedIndex) {
                    ForEach(0..<5) { i in
                        Text("Tab \(i + 1)").tag(i)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 290)
            }
            ToolbarItemGroup(placement: .automatic) {
                PaneToggleButton(
                    icon: "rectangle.lefthalf.inset.filled",
                    active: store.current.showLeft,
                    help: "Left Pane"
                ) {
                    store.current.showLeft.toggle()
                    if !store.current.showLeft { store.current.leftWindow = nil }
                }
                PaneToggleButton(
                    icon: "rectangle.righthalf.inset.filled",
                    active: store.current.showRight,
                    help: "Right Pane"
                ) {
                    store.current.showRight.toggle()
                    if !store.current.showRight { store.current.rightWindow = nil }
                }
                PaneToggleButton(
                    icon: "rectangle.bottomhalf.inset.filled",
                    active: store.current.showBottom,
                    help: "Bottom Pane"
                ) {
                    store.current.showBottom.toggle()
                    if !store.current.showBottom { store.current.bottomWindow = nil }
                }
            }
        }
    }

    private func checkPermission() async {
        do {
            _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            permissionGranted = true
        } catch {
            permissionGranted = false
        }
    }
}

private struct PaneToggleButton: View {
    let icon: String
    let active: Bool
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .foregroundStyle(active ? Color.accentColor : Color.secondary)
        }
        .help(help)
    }
}
