import Foundation

enum MenuBarBridgeProtocol {
    static let helperBundleIdentifier = "com.qingcheng.monolist.menubar.v2"
    static let statusItemAutosaveName = "MonoList.MenuBarService.v2"
    static let showMainPanel = Notification.Name(
        "com.qingcheng.monolist.menubar.v2.showMainPanel"
    )
    static let openSettings = Notification.Name(
        "com.qingcheng.monolist.menubar.v2.openSettings"
    )
    static let pendingCountChanged = Notification.Name(
        "com.qingcheng.monolist.menubar.v2.pendingCountChanged"
    )
    static let statusItemFrameChanged = Notification.Name(
        "com.qingcheng.monolist.menubar.v2.statusItemFrameChanged"
    )
    static let quit = Notification.Name(
        "com.qingcheng.monolist.menubar.v2.quit"
    )

    static func title(pendingCount: Int) -> String {
        pendingCount == 0 ? "" : "\(pendingCount)"
    }

    static func title(pendingCount: Int, focusRemainingCount: Int?) -> String {
        guard let focusRemainingCount else {
            return title(pendingCount: pendingCount)
        }
        return focusRemainingCount == 0 ? "专注 ✓" : "专注 \(focusRemainingCount)"
    }

    static func toolTip(currentFocusText: String?, focusCompleted: Bool) -> String {
        if focusCompleted {
            return "今日专注已完成"
        }
        if let currentFocusText, !currentFocusText.isEmpty {
            return "当前专注：\(currentFocusText)"
        }
        return "MonoList"
    }
}
