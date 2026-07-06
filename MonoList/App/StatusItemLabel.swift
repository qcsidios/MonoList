import AppKit

enum StatusItemLabel {
    @MainActor
    static func attributedTitle(pendingCount: Int) -> NSAttributedString {
        let font = NSFont.menuBarFont(ofSize: 0)
        let result = NSMutableAttributedString(
            string: "待办",
            attributes: [
                .font: font,
                .foregroundColor: NSColor.labelColor,
            ]
        )
        guard pendingCount > 0 else {
            return result
        }

        result.append(NSAttributedString(string: " "))
        let attachment = NSTextAttachment()
        let image = badgeImage(text: String(pendingCount))
        attachment.image = image
        attachment.bounds = NSRect(
            x: 0,
            y: -3,
            width: image.size.width,
            height: image.size.height
        )
        result.append(NSAttributedString(attachment: attachment))
        return result
    }

    static func accessibilityTitle(pendingCount: Int) -> String {
        pendingCount == 0 ? "待办" : "待办 \(pendingCount)"
    }

    @MainActor
    private static func badgeImage(text: String) -> NSImage {
        let badgeFont = NSFont.systemFont(ofSize: 10, weight: .semibold)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: badgeFont,
            .foregroundColor: NSColor.white,
        ]
        let textSize = (text as NSString).size(withAttributes: attributes)
        let size = NSSize(
            width: max(16, ceil(textSize.width) + 8),
            height: 16
        )
        return NSImage(size: size, flipped: false) { rect in
            NSColor.systemOrange.setFill()
            NSBezierPath(
                roundedRect: rect.insetBy(dx: 0, dy: 1),
                xRadius: 7,
                yRadius: 7
            ).fill()
            let textRect = NSRect(
                x: (rect.width - textSize.width) / 2,
                y: (rect.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            (text as NSString).draw(in: textRect, withAttributes: attributes)
            return true
        }
    }
}
