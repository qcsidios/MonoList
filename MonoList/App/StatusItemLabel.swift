import AppKit

enum StatusItemLabel {
    static func title(pendingCount: Int) -> String {
        pendingCount == 0 ? "待办" : "待办 \(pendingCount)"
    }

    static func accessibilityTitle(pendingCount: Int) -> String {
        pendingCount == 0 ? "待办" : "待办 \(pendingCount)"
    }
}
