import Foundation

@main
struct MenuBarBridgeSmoke {
    static func main() {
        precondition(MenuBarBridgeProtocol.helperBundleIdentifier ==
            "com.qingcheng.monolist.menubar")
        precondition(MenuBarBridgeProtocol.title(pendingCount: 0) == "待办")
        precondition(MenuBarBridgeProtocol.title(pendingCount: 3) == "待办 3")
        precondition(MenuBarBridgeProtocol.showMainPanel.rawValue.hasPrefix(
            "com.qingcheng.monolist."
        ))
        precondition(MenuBarBridgeProtocol.openSettings.rawValue.hasPrefix(
            "com.qingcheng.monolist."
        ))
        precondition(MenuBarBridgeProtocol.pendingCountChanged.rawValue.hasPrefix(
            "com.qingcheng.monolist."
        ))
        precondition(MenuBarBridgeProtocol.statusItemFrameChanged.rawValue.hasPrefix(
            "com.qingcheng.monolist."
        ))
        precondition(MenuBarBridgeProtocol.quit.rawValue.hasPrefix(
            "com.qingcheng.monolist."
        ))

        print("Menu bar bridge smoke passed.")
    }
}
