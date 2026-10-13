#!/usr/bin/env swift
//
// Generates a branded marketing banner (gold/vintage) reusing the app icon.
// Usage: swift scripts/marketing_banner.swift [de|en] [out.png]
//
import AppKit
import CoreGraphics
import Foundation

let lang = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "de"
let outPath = CommandLine.arguments.count > 2
    ? CommandLine.arguments[2]
    : "Screenshots/marketing-\(lang).png"

let W = 2400, H = 1260
let scale = 1

func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(red: r, green: g, blue: b, alpha: a)
}

guard let ctx = CGContext(
    data: nil, width: W * scale, height: H * scale,
    bitsPerComponent: 8, bytesPerRow: 0,
    space: CGColorSpace(name: CGColorSpace.sRGB)!,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { fatalError("ctx") }
ctx.scaleBy(x: CGFloat(scale), y: CGFloat(scale))

// Warm dark gradient background
let cs = CGColorSpace(name: CGColorSpace.sRGB)!
let bg = CGGradient(colorsSpace: cs, colors: [
    color(0.10, 0.08, 0.06), color(0.05, 0.045, 0.04)
] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(bg, start: CGPoint(x: 0, y: CGFloat(H)), end: CGPoint(x: CGFloat(W), y: 0), options: [])

// Gold radial glow behind the icon
let glow = CGGradient(colorsSpace: cs, colors: [
    color(0.89, 0.70, 0.33, 0.45), color(0.89, 0.70, 0.33, 0.0)
] as CFArray, locations: [0, 1])!
ctx.drawRadialGradient(glow, startCenter: CGPoint(x: 620, y: CGFloat(H) - 630), startRadius: 0,
                       endCenter: CGPoint(x: 620, y: CGFloat(H) - 630), endRadius: 560, options: [])

// App icon (reuse the polished asset)
let iconPath = "Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
if let img = NSImage(contentsOfFile: iconPath),
   let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil) {
    let side: CGFloat = 520
    let rect = CGRect(x: 360, y: CGFloat(H) - 630 - side / 2, width: side, height: side)
    let clip = CGPath(roundedRect: rect, cornerWidth: side * 0.22, cornerHeight: side * 0.22, transform: nil)
    ctx.saveGState(); ctx.addPath(clip); ctx.clip()
    ctx.draw(cg, in: rect)
    ctx.restoreGState()
}

// Text via AppKit
let ns = NSGraphicsContext(cgContext: ctx, flipped: false)
NSGraphicsContext.current = ns

let title = "Sprechly"
let tagline = lang == "en" ? "Record. Transcribe. AI — on your iPhone." : "Aufnehmen. Transkribieren. KI — auf deinem iPhone."
let sub = lang == "en" ? "On-device. No subscription." : "On-Device. Kein Abo."

let titleAttr: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 168, weight: .bold),
    .foregroundColor: NSColor.white
]
let taglineAttr: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 72, weight: .medium),
    .foregroundColor: NSColor(red: 0.89, green: 0.70, blue: 0.33, alpha: 1)
]
let subAttr: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 52, weight: .regular),
    .foregroundColor: NSColor(white: 1, alpha: 0.65)
]

let tx: CGFloat = 1000
NSString(string: title).draw(at: CGPoint(x: tx, y: CGFloat(H) - 470), withAttributes: titleAttr)
NSString(string: tagline).draw(in: CGRect(x: tx, y: CGFloat(H) - 660, width: 1300, height: 200), withAttributes: taglineAttr)
NSString(string: sub).draw(at: CGPoint(x: tx, y: CGFloat(H) - 760), withAttributes: subAttr)

NSGraphicsContext.current = nil

guard let out = ctx.makeImage() else { fatalError("image") }
let url = URL(fileURLWithPath: outPath)
try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
guard let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else { fatalError("dest") }
CGImageDestinationAddImage(dest, out, nil)
CGImageDestinationFinalize(dest)
print("Wrote \(outPath)")
