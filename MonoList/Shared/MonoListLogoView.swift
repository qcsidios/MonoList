import AppKit
import SwiftUI

struct MonoListLogoView: View {
    var size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .fill(.black)

            Canvas { context, canvasSize in
                let scale = canvasSize.width / 100
                let lineWidth = 5.2 * scale
                let radius = 11.5 * scale
                let circleX = 29 * scale
                let firstY = 34 * scale
                let secondY = 66 * scale

                for y in [firstY, secondY] {
                    let circleRect = CGRect(
                        x: circleX - radius,
                        y: y - radius,
                        width: radius * 2,
                        height: radius * 2
                    )
                    context.stroke(
                        Path(ellipseIn: circleRect),
                        with: .color(.white),
                        lineWidth: lineWidth
                    )

                    var line = Path()
                    line.move(to: CGPoint(x: 51 * scale, y: y))
                    line.addLine(to: CGPoint(x: 79 * scale, y: y))
                    context.stroke(
                        line,
                        with: .color(.white),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                }

                var check = Path()
                check.move(to: CGPoint(x: 23 * scale, y: 66 * scale))
                check.addLine(to: CGPoint(x: 28 * scale, y: 71 * scale))
                check.addLine(to: CGPoint(x: 36 * scale, y: 60 * scale))
                context.stroke(
                    check,
                    with: .color(.white),
                    style: StrokeStyle(
                        lineWidth: 3.8 * scale,
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
