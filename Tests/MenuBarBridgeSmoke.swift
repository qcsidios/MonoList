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
        precondition(
            MenuBarBridgeProtocol.title(pendingCount: 8, focusRemainingCount: 2) ==
                "专注 2"
        )
        precondition(
            MenuBarBridgeProtocol.title(pendingCount: 8, focusRemainingCount: 0) ==
                "专注 ✓"
        )
        precondition(
            MenuBarBridgeProtocol.toolTip(
                currentFocusText: "写完规格",
                focusCompleted: false
            ) == "当前专注：写完规格"
        )
        precondition(
            MenuBarBridgeProtocol.toolTip(
                currentFocusText: nil,
                focusCompleted: true
            ) == "今日专注已完成"
        )
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
