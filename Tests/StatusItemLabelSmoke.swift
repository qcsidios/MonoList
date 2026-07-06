import AppKit

@main
struct StatusItemLabelSmoke {
    @MainActor
    static func main() {
        _ = NSApplication.shared

        let empty = StatusItemLabel.attributedTitle(pendingCount: 0)
        precondition(empty.string == "待办")
        precondition(
            empty.attribute(
                .attachment,
                at: 0,
                effectiveRange: nil
            ) == nil
        )

        let active = StatusItemLabel.attributedTitle(pendingCount: 12)
        precondition(active.string.hasPrefix("待办 "))
        let attachmentIndex = active.length - 1
        precondition(
            active.attribute(
                .attachment,
                at: attachmentIndex,
                effectiveRange: nil
            ) is NSTextAttachment
        )
        precondition(StatusItemLabel.accessibilityTitle(pendingCount: 12) == "待办 12")

        print("Status item label smoke passed.")
    }
}
