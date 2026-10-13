#!/usr/bin/env swift
//
// Renders the branded overlays for the social promo video (1080x1920):
//   intro.png, outro.png (opaque cards) and cap1..cap4.png (transparent
//   lower-third captions). CoreGraphics + AppKit, gold/vintage brand look.
//
// Usage: swift scripts/promo_assets.swift [de|en] <outdir>
//
import AppKit
import CoreGraphics
import Foundation

let lang = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "de"
let outDir = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "/tmp/promo-assets"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

let W = 1080, H = 1920
let cs = CGColorSpace(name: CGColorSpace.sRGB)!
func col(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(red: r, green: g, blue: b, alpha: a)
}
let gold = NSColor(red: 0.89, green: 0.70, blue: 0.33, alpha: 1)
let goldBright = NSColor(red: 1.0, green: 0.82, blue: 0.38, alpha: 1)

func roundedFont(_ size: CGFloat, _ weight: NSFont.Weight) -> NSFont {
    let base = NSFont.systemFont(ofSize: size, weight: weight)
    if let d = base.fontDescriptor.withDesign(.rounded) { return NSFont(descriptor: d, size: size) ?? base }
    return base
}

func newContext(opaque: Bool) -> CGContext {
    let ctx = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0,
                        space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    return ctx
}

func save(_ ctx: CGContext, _ name: String) {
    guard let cg = ctx.makeImage() else { return }
    let rep = NSBitmapImageRep(cgImage: cg)
    guard let data = rep.representation(using: .png, properties: [:]) else { return }
    try? data.write(to: URL(fileURLWithPath: "\(outDir)/\(name)"))
    print("  \(outDir)/\(name)")
}

/// Centered attributed text; returns drawn height.
@discardableResult
func drawCentered(_ ctx: CGContext, _ text: String, font: NSFont, color: NSColor,
                  centerX: CGFloat, baselineY: CGFloat, tracking: CGFloat = 0) -> CGSize {
    let ns = NSGraphicsContext(cgContext: ctx, flipped: false)
    NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = ns
    let para = NSMutableParagraphStyle(); para.alignment = .center
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font, .foregroundColor: color, .paragraphStyle: para, .kern: tracking
    ]
    let s = NSAttributedString(string: text, attributes: attrs)
    let size = s.size()
    s.draw(at: CGPoint(x: centerX - size.width / 2, y: baselineY))
    NSGraphicsContext.restoreGraphicsState()
    return size
}

func drawBackground(_ ctx: CGContext, glowY: CGFloat) {
    let bg = CGGradient(colorsSpace: cs, colors: [col(0.10, 0.08, 0.06), col(0.045, 0.04, 0.035)] as CFArray,
                        locations: [0, 1])!
    ctx.drawLinearGradient(bg, start: CGPoint(x: 0, y: CGFloat(H)), end: CGPoint(x: CGFloat(W), y: 0), options: [])
    let glow = CGGradient(colorsSpace: cs, colors: [col(0.89, 0.70, 0.33, 0.40), col(0.89, 0.70, 0.33, 0)] as CFArray,
                          locations: [0, 1])!
    ctx.drawRadialGradient(glow, startCenter: CGPoint(x: CGFloat(W) / 2, y: glowY), startRadius: 0,
                           endCenter: CGPoint(x: CGFloat(W) / 2, y: glowY), endRadius: 620, options: [])
}

func drawIcon(_ ctx: CGContext, center: CGPoint, side: CGFloat) {
    let path = "Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
    guard let img = NSImage(contentsOfFile: path),
          let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
    let rect = CGRect(x: center.x - side / 2, y: center.y - side / 2, width: side, height: side)
    let clip = CGPath(roundedRect: rect, cornerWidth: side * 0.22, cornerHeight: side * 0.22, transform: nil)
    ctx.saveGState(); ctx.addPath(clip); ctx.clip(); ctx.draw(cg, in: rect); ctx.restoreGState()
}

// MARK: - Intro card
do {
    let ctx = newContext(opaque: true)
    drawBackground(ctx, glowY: CGFloat(H) - 720)
    drawIcon(ctx, center: CGPoint(x: CGFloat(W) / 2, y: CGFloat(H) - 720), side: 380)
    drawCentered(ctx, "Sprechly", font: roundedFont(140, .bold), color: .white,
                 centerX: CGFloat(W) / 2, baselineY: CGFloat(H) - 1040)
    let tagline = lang == "en" ? "Speak. Sprechly writes it down." : "Sprich. Sprechly schreibt mit."
    drawCentered(ctx, tagline, font: roundedFont(52, .medium), color: gold,
                 centerX: CGFloat(W) / 2, baselineY: CGFloat(H) - 1140)
    let sub = lang == "en" ? "Record · Transcribe · AI — on-device" : "Aufnehmen · Transkribieren · KI — on-device"
    drawCentered(ctx, sub, font: roundedFont(38, .regular), color: NSColor(white: 1, alpha: 0.65),
                 centerX: CGFloat(W) / 2, baselineY: 250)
    save(ctx, "intro.png")
}

// MARK: - Outro card (CTA)
do {
    let ctx = newContext(opaque: true)
    drawBackground(ctx, glowY: CGFloat(H) - 640)
    drawIcon(ctx, center: CGPoint(x: CGFloat(W) / 2, y: CGFloat(H) - 640), side: 340)
    drawCentered(ctx, "Sprechly", font: roundedFont(128, .bold), color: .white,
                 centerX: CGFloat(W) / 2, baselineY: CGFloat(H) - 960)
    let sub = lang == "en" ? "Recording · Transcript · AI · 100% on-device"
                           : "Aufnahme · Transkript · KI · 100% on-device"
    drawCentered(ctx, sub, font: roundedFont(40, .medium), color: NSColor(white: 1, alpha: 0.7),
                 centerX: CGFloat(W) / 2, baselineY: CGFloat(H) - 1060)

    // Gold CTA pill
    let cta = lang == "en" ? "Download free" : "Jetzt gratis laden"
    let ctaFont = roundedFont(54, .bold)
    let ctaSize = NSAttributedString(string: cta, attributes: [.font: ctaFont]).size()
    let pillW = ctaSize.width + 130, pillH: CGFloat = 130
    let pillRect = CGRect(x: (CGFloat(W) - pillW) / 2, y: 470, width: pillW, height: pillH)
    let pill = CGPath(roundedRect: pillRect, cornerWidth: pillH / 2, cornerHeight: pillH / 2, transform: nil)
    ctx.addPath(pill)
    ctx.setFillColor(gold.cgColor); ctx.fillPath()
    drawCentered(ctx, cta, font: ctaFont, color: NSColor(red: 0.12, green: 0.09, blue: 0.04, alpha: 1),
                 centerX: CGFloat(W) / 2, baselineY: 470 + (pillH - ctaSize.height) / 2)
    let noAbo = lang == "en" ? "No subscription" : "Kein Abo"
    drawCentered(ctx, noAbo, font: roundedFont(36, .regular), color: NSColor(white: 1, alpha: 0.55),
                 centerX: CGFloat(W) / 2, baselineY: 360)
    save(ctx, "outro.png")
}

// MARK: - Caption lower-thirds (transparent)
let captions: [String] = lang == "en"
    ? ["Speak — Sprechly writes it down", "Record like a pro dictaphone",
       "Transcript & AI — on-device", "No subscription · no servers"]
    : ["Sprich – Sprechly schreibt mit", "Aufnehmen wie ein Profi-Diktiergerät",
       "Transkript & KI – on-device", "Kein Abo · keine Server"]

for (i, text) in captions.enumerated() {
    let ctx = newContext(opaque: false)
    let font = roundedFont(58, .bold)
    let tsize = NSAttributedString(string: text, attributes: [.font: font]).size()
    let barH: CGFloat = 150
    let barW = min(CGFloat(W) - 80, tsize.width + 180)
    let barX = (CGFloat(W) - barW) / 2
    let barY: CGFloat = 360 // from bottom
    // Frosted dark bar
    let r = CGRect(x: barX, y: barY, width: barW, height: barH)
    ctx.addPath(CGPath(roundedRect: r, cornerWidth: 34, cornerHeight: 34, transform: nil))
    ctx.setFillColor(col(0.08, 0.07, 0.06, 0.82)); ctx.fillPath()
    // Gold left accent
    let acc = CGRect(x: barX + 26, y: barY + 32, width: 10, height: barH - 64)
    ctx.addPath(CGPath(roundedRect: acc, cornerWidth: 5, cornerHeight: 5, transform: nil))
    ctx.setFillColor(goldBright.cgColor); ctx.fillPath()
    drawCentered(ctx, text, font: font, color: .white,
                 centerX: CGFloat(W) / 2 + 18, baselineY: barY + (barH - tsize.height) / 2)
    save(ctx, "cap\(i + 1).png")
}

print("Promo assets → \(outDir)")
