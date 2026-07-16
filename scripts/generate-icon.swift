#!/usr/bin/swift

import AppKit
import CoreGraphics

// MARK: - Icon drawing

func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    let rect = CGRect(x: 0, y: 0, width: size, height: size)
    let cornerRadius = size * 0.2237 // macOS squircle approximation

    // Background gradient (deep blue to deep purple)
    let bgPath = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
    ctx.addPath(bgPath)
    ctx.clip()

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let gradientColors = [
        CGColor(red: 0.10, green: 0.10, blue: 0.31, alpha: 1.0), // #1a1a4e
        CGColor(red: 0.23, green: 0.10, blue: 0.37, alpha: 1.0), // #3a1a5e
    ] as CFArray
    let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: [0.0, 1.0])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: size), end: CGPoint(x: size, y: 0), options: [])

    // Moon crescent (gold)
    let center = CGPoint(x: size * 0.48, y: size * 0.50)
    let outerRadius = size * 0.30
    let innerRadius = size * 0.24
    let innerOffset = CGPoint(x: size * 0.10, y: size * 0.06)

    let moonPath = CGMutablePath()
    // Outer circle (full moon)
    moonPath.addArc(center: center, radius: outerRadius, startAngle: 0, endAngle: .pi * 2, clockwise: false)
    // Inner circle (subtracted to make crescent) — shifted right and up
    let innerCenter = CGPoint(x: center.x + innerOffset.x, y: center.y + innerOffset.y)
    moonPath.addArc(center: innerCenter, radius: innerRadius, startAngle: 0, endAngle: .pi * 2, clockwise: true)

    ctx.resetClip()
    ctx.addPath(bgPath)
    ctx.clip()

    ctx.setFillColor(CGColor(red: 1.0, green: 0.835, blue: 0.31, alpha: 1.0)) // #FFD54F
    ctx.addPath(moonPath)
    ctx.fillPath(using: .evenOdd)

    // Prohibition line (red-orange diagonal stroke)
    let lineWidth = size * 0.07
    let padding = size * 0.22
    let lineStart = CGPoint(x: padding, y: size - padding)
    let lineEnd = CGPoint(x: size - padding, y: padding)

    ctx.setStrokeColor(CGColor(red: 0.90, green: 0.22, blue: 0.21, alpha: 1.0)) // #E53935
    ctx.setLineWidth(lineWidth)
    ctx.setLineCap(.round)
    ctx.beginPath()
    ctx.move(to: lineStart)
    ctx.addLine(to: lineEnd)
    ctx.strokePath()

    image.unlockFocus()
    return image
}

// MARK: - Generate iconset

let sizes: [(name: String, size: CGFloat)] = [
    ("icon_16x16", 16),
    ("icon_16x16@2x", 32),
    ("icon_32x32", 32),
    ("icon_32x32@2x", 64),
    ("icon_128x128", 128),
    ("icon_128x128@2x", 256),
    ("icon_256x256", 256),
    ("icon_256x256@2x", 512),
    ("icon_512x512", 512),
    ("icon_512x512@2x", 1024),
]

let scriptDir = URL(fileURLWithPath: #file).deletingLastPathComponent()
let iconsetDir = scriptDir.appendingPathComponent("AppIcon.iconset")
let icnsPath = scriptDir.appendingPathComponent("AppIcon.icns")

// Create iconset directory
let fm = FileManager.default
try? fm.removeItem(at: iconsetDir)
try fm.createDirectory(at: iconsetDir, withIntermediateDirectories: true)

for entry in sizes {
    let image = drawIcon(size: entry.size)
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        print("❌ Failed to generate \(entry.name)")
        exit(1)
    }
    let filePath = iconsetDir.appendingPathComponent("\(entry.name).png")
    try png.write(to: filePath)
}

print("✅ Generated iconset at \(iconsetDir.path)")

// Convert to icns
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["--convert", "icns", "--output", icnsPath.path, iconsetDir.path]
try process.run()
process.waitUntilExit()

if process.terminationStatus == 0 {
    // Clean up iconset directory
    try? fm.removeItem(at: iconsetDir)
    print("✅ Generated \(icnsPath.path)")
} else {
    print("❌ iconutil failed with status \(process.terminationStatus)")
    exit(1)
}
