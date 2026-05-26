import Foundation
import ScreenCaptureKit
import Combine

final class TabLayout: ObservableObject {
    let tabNumber: Int

    @Published var mainWindow:   SCWindow?
    @Published var leftWindow:   SCWindow?
    @Published var rightWindow:  SCWindow?
    @Published var bottomWindow: SCWindow?

    @Published var showLeft   = false
    @Published var showRight  = false
    @Published var showBottom = false

    @Published var leftWidth:    CGFloat = 260
    @Published var rightWidth:   CGFloat = 260
    @Published var bottomHeight: CGFloat = 220

    init(number: Int) {
        self.tabNumber = number
    }

    func setWindow(_ window: SCWindow?, for role: PaneRole) {
        switch role {
        case .main:   mainWindow   = window
        case .left:   leftWindow   = window; if window == nil { showLeft   = false }
        case .right:  rightWindow  = window; if window == nil { showRight  = false }
        case .bottom: bottomWindow = window; if window == nil { showBottom = false }
        }
    }

    func window(for role: PaneRole) -> SCWindow? {
        switch role {
        case .main:   return mainWindow
        case .left:   return leftWindow
        case .right:  return rightWindow
        case .bottom: return bottomWindow
        }
    }

    func swapWindows(source: PaneRole, dest: PaneRole) {
        let srcWindow  = window(for: source)
        let destWindow = window(for: dest)
        assignWindow(destWindow, to: source)
        assignWindow(srcWindow,  to: dest)
    }

    private func assignWindow(_ window: SCWindow?, to role: PaneRole) {
        switch role {
        case .main:   mainWindow   = window
        case .left:   leftWindow   = window
        case .right:  rightWindow  = window
        case .bottom: bottomWindow = window
        }
    }
}
