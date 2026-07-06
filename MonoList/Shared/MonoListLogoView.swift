import AppKit
import SwiftUI

struct MonoListLogoView: View {
    var size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .fill(.white)
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                        .stroke(Color.black.opacity(0.16), lineWidth: 0.5)
                )

            Canvas { context, canvasSize in
                let scale = canvasSize.width / 100
                let lineWidth = 5.2 * scale
                let radius = 22 * scale
                let center = CGPoint(x: 50 * scale, y: 50 * scale)
                let circleRect = CGRect(
                    x: center.x - radius,
                    y: center.y - radius,
                    width: radius * 2,
                    height: radius * 2
                )
                context.stroke(
                    Path(ellipseIn: circleRect),
                    with: .color(.black),
                    lineWidth: lineWidth
                )

                var check = Path()
                check.move(to: CGPoint(x: 38 * scale, y: 50 * scale))
                check.addLine(to: CGPoint(x: 47 * scale, y: 59 * scale))
                check.addLine(to: CGPoint(x: 63 * scale, y: 40 * scale))
                context.stroke(
                    check,
                    with: .color(.black),
                    style: StrokeStyle(
                        lineWidth: lineWidth,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
            }
        }
        .frame(width: size, height: size)
    }
}

enum MonoListLogoRenderer {
    @MainActor
    static func makeImage(size: CGFloat) -> NSImage {
        let view = MonoListLogoView(size: size)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        return renderer.nsImage ?? NSImage(size: NSSize(width: size, height: size))
    }
}
