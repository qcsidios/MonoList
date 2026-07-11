import Foundation

enum MenuBarBridgeProtocol {
    static let helperBundleIdentifier = "com.qingcheng.monolist.menubar"
    static let showMainPanel = Notification.Name(
        "com.qingcheng.monolist.showMainPanel"
    )
    static let openSettings = Notification.Name(
        "com.qingcheng.monolist.openSettings"
    )
    static let pendingCountChanged = Notification.Name(
        "com.qingcheng.monolist.pendingCountChanged"
    )
    static let statusItemFrameChanged = Notification.Name(
        "com.qingcheng.monolist.statusItemFrameChanged"
    )
    static let quit = Notification.Name(
        "com.qingcheng.monolist.quit"
    )

    static func title(pendingCount: Int) -> String {
        pendingCount == 0 ? "" : "\(pendingCount)"
    }
}
