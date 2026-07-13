import Foundation

@main
struct MenuBarBridgeSmoke {
    static func main() {
        precondition(
            MenuBarBridgeProtocol.helperBundleIdentifier ==
                "com.qingcheng.monolist.menubar.v2"
        )
        precondition(
            MenuBarBridgeProtocol.statusItemAutosaveName ==
                "MonoList.MenuBarService.v2"
        )
        precondition(MenuBarBridgeProtocol.title(pendingCount: 0).isEmpty)
        precondition(MenuBarBridgeProtocol.title(pendingCount: 3) == "3")
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
