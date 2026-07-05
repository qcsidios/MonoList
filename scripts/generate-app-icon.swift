#!/usr/bin/env swift

import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else {
    fputs("用法：generate-app-icon.swift <AppIcon.iconset>\n", stderr)
    exit(1)
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(
    at: outputURL,
    withIntermediateDirectories: true
)

let variants: [(name: String, pixels: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

for variant in variants {
    let pixels = variant.pixels
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw CocoaError(.fileWriteUnknown)
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    let scale = CGFloat(pixels) / 100
    let fullRect = NSRect(x: 0, y: 0, width: pixels, height: pixels)
    NSColor.clear.setFill()
    fullRect.fill()

    NSColor.black.setFill()
    NSBezierPath(
        roundedRect: fullRect.insetBy(dx: 4 * scale, dy: 4 * scale),
        xRadius: 23 * scale,
        yRadius: 23 * scale
    ).fill()

    let strokeWidth = max(1, 5.2 * scale)
    let radius = 11.5 * scale
    let circleX = 29 * scale
    let rowYs = [66 * scale, 34 * scale]
    NSColor.white.setStroke()

    for y in rowYs {
        let circle = NSBezierPath(
            ovalIn: NSRect(
                x: circleX - radius,
                y: y - radius,
                width: radius * 2,
                height: radius * 2
            )
        )
        circle.lineWidth = strokeWidth
        circle.stroke()

        let line = NSBezierPath()
        line.lineCapStyle = .round
        line.lineWidth = strokeWidth
        line.move(to: NSPoint(x: 51 * scale, y: y))
        line.line(to: NSPoint(x: 79 * scale, y: y))
        line.stroke()
    }

    let check = NSBezierPath()
    check.lineCapStyle = .round
    check.lineJoinStyle = .round
    check.lineWidth = max(1, 3.8 * scale)
    check.move(to: NSPoint(x: 23 * scale, y: 34 * scale))
    check.line(to: NSPoint(x: 28 * scale, y: 29 * scale))
    check.line(to: NSPoint(x: 36 * scale, y: 40 * scale))
    check.stroke()
    NSGraphicsContext.restoreGraphicsState()

    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw CocoaError(.fileWriteUnknown)
    }
    try data.write(to: outputURL.appendingPathComponent(variant.name))
}
