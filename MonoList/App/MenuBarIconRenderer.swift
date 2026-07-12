import AppKit

enum MenuBarIconRenderer {
    static func makeImage() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { rect in
            NSColor.black.setStroke()
            let circle = NSBezierPath(ovalIn: rect.insetBy(dx: 2.5, dy: 2.5))
            circle.lineWidth = 1.7
            circle.stroke()

            let check = NSBezierPath()
            check.move(to: NSPoint(x: 5.8, y: 9.1))
            check.line(to: NSPoint(x: 8.1, y: 6.8))
            check.line(to: NSPoint(x: 12.4, y: 11.5))
            check.lineWidth = 1.7
            check.lineCapStyle = .round
            check.lineJoinStyle = .round
            check.stroke()
            return true
        }
        image.isTemplate = true
        return image
    }
}
