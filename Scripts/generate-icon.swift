#!/usr/bin/env swift
// Generates Resources/AppIcon.iconset PNGs (run once, then
// `iconutil -c icns Resources/AppIcon.iconset -o Resources/AppIcon.icns`).
// Mist brand mark: a white fog glyph over a cool blue-gray dusk gradient.
import AppKit
import Foundation

let sizes: [(Int, String)] = [
    (16, "icon_16x16"),
    (32, "icon_16x16@2x"),
    (32, "icon_32x32"),
    (64, "icon_32x32@2x"),
    (128, "icon_128x128"),
    (256, "icon_128x128@2x"),
    (256, "icon_256x256"),
    (512, "icon_256x256@2x"),
    (512, "icon_512x512"),
    (1024, "icon_512x512@2x")
]

let outputDir = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Resources/AppIcon.iconset")
try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

func drawIcon(size: Int) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    let cornerRadius = CGFloat(size) * 0.22
    let path = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)

    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.13, green: 0.17, blue: 0.28, alpha: 1.0),
        NSColor(calibratedRed: 0.42, green: 0.58, blue: 0.78, alpha: 1.0)
    ])
    gradient?.draw(in: path, angle: -60)

    let symbolConfig = NSImage.SymbolConfiguration(pointSize: CGFloat(size) * 0.52, weight: .semibold)
    if let symbol = NSImage(systemSymbolName: "cloud.fog.fill", accessibilityDescription: nil)?
        .withSymbolConfiguration(symbolConfig) {
        let symbolSize = symbol.size
        let symbolRect = NSRect(
            x: (CGFloat(size) - symbolSize.width) / 2,
            y: (CGFloat(size) - symbolSize.height) / 2,
            width: symbolSize.width,
            height: symbolSize.height
        )

        // Stencil the symbol's alpha shape with solid white — drawing the SF
        // Symbol directly renders black regardless of isTemplate/tint color
        // via this old draw(in:from:operation:) API, so mask instead.
        let whiteGlyph = NSImage(size: symbolSize)
        whiteGlyph.lockFocus()
        NSColor.white.withAlphaComponent(0.95).set()
        NSRect(origin: .zero, size: symbolSize).fill()
        symbol.draw(at: .zero, from: .zero, operation: .destinationIn, fraction: 1.0)
        whiteGlyph.unlockFocus()

        whiteGlyph.draw(in: symbolRect, from: .zero, operation: .sourceOver, fraction: 1.0)
    }

    image.unlockFocus()
    return image
}

for (size, name) in sizes {
    let image = drawIcon(size: size)
    guard let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        continue
    }
    let fileURL = outputDir.appendingPathComponent("\(name).png")
    try? png.write(to: fileURL)
    print("wrote \(fileURL.lastPathComponent)")
}
