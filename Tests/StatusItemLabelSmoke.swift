import AppKit

@main
struct StatusItemLabelSmoke {
    @MainActor
    static func main() {
        _ = NSApplication.shared

        precondition(StatusItemLabel.title(pendingCount: 0) == "待办")
        precondition(StatusItemLabel.title(pendingCount: 12) == "待办 12")
        precondition(StatusItemLabel.accessibilityTitle(pendingCount: 12) == "待办 12")

        print("Status item label smoke passed.")
    }
}
