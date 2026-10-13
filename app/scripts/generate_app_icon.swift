#!/usr/bin/env swift
import AppKit
import CoreGraphics

// Renders the Sprechly Work app icon (1024×1024, no alpha) to the path given as the
// first argument. Deep indigo→blue gradient with a centered, softly glowing
// waveform — matches the app's dark-first accent palette.

let outPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "AppIcon.png"

let pixels = 1024
let S = CGFloat(pixels)
let cs = CGColorSpaceCreateDeviceRGB()

guard let ctx = CGContext(
    data: nil,
    width: pixels,
    height: pixels,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: cs,
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
) else { fatalError("Could not create context") }

func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: cs, components: [r, g, b, a])!
}

// Background: diagonal gradient (top-left deep indigo → bottom-right vivid blue).
let bgColors = [
    color(0.09, 0.10, 0.26),
    color(0.25, 0.22, 0.56),
    color(0.36, 0.46, 1.00)
] as CFArray
let bg = CGGradient(colorsSpace: cs, colors: bgColors, locations: [0.0, 0.55, 1.0])!
ctx.drawLinearGradient(bg, start: CGPoint(x: 0, y: S), end: CGPoint(x: S, y: 0), options: [])

// Soft radial glow behind the waveform.
let glowColors = [
    color(0.58, 0.65, 1.0, 0.50),
    color(0.58, 0.65, 1.0, 0.0)
] as CFArray
let glow = CGGradient(colorsSpace: cs, colors: glowColors, locations: [0, 1])!
ctx.drawRadialGradient(
    glow,
    startCenter: CGPoint(x: S / 2, y: S / 2), startRadius: 0,
    endCenter: CGPoint(x: S / 2, y: S / 2), endRadius: S * 0.44,
    options: []
)

// Waveform: symmetric bell of rounded capsules with a soft blue glow.
let heights: [CGFloat] = [0.16, 0.28, 0.45, 0.66, 0.86, 1.0, 0.86, 0.66, 0.45, 0.28, 0.16]
let maxBarHeight = S * 0.48
let barWidth = S * 0.046
let gap = S * 0.028
let totalWidth = CGFloat(heights.count) * barWidth + CGFloat(heights.count - 1) * gap
var x = (S - totalWidth) / 2
let midY = S / 2

ctx.setShadow(offset: .zero, blur: 30, color: color(0.70, 0.80, 1.0, 0.9))
ctx.setFillColor(color(1, 1, 1, 1))

for h in heights {
    let barHeight = max(barWidth, maxBarHeight * h)
    let rect = CGRect(x: x, y: midY - barHeight / 2, width: barWidth, height: barHeight)
    let path = CGPath(
        roundedRect: rect,
        cornerWidth: barWidth / 2,
        cornerHeight: barWidth / 2,
        transform: nil
    )
    ctx.addPath(path)
    ctx.fillPath()
    x += barWidth + gap
}

guard let image = ctx.makeImage() else { fatalError("Could not render image") }
let rep = NSBitmapImageRep(cgImage: image)
guard let data = rep.representation(using: .png, properties: [:]) else {
    fatalError("Could not encode PNG")
}
try! data.write(to: URL(fileURLWithPath: outPath))
print("Wrote \(outPath) (\(pixels)×\(pixels))")
