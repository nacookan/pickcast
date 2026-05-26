import SwiftUI

@main
struct PickcastApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowToolbarStyle(.unifiedCompact(showsTitle: false))
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(replacing: .undoRedo) {}
            CommandGroup(replacing: .pasteboard) {}
            CommandGroup(replacing: .help) {}
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        DispatchQueue.main.async { self.removeUnneededMenus() }
    }

    private func removeUnneededMenus() {
        guard let menu = NSApp.mainMenu else { return }
        for title in ["Edit", "Help"] {
            if let item = menu.items.first(where: { $0.title == title }) {
                menu.removeItem(item)
            }
        }
    }
}
