#!/usr/bin/env swift
import AppKit
import CoreGraphics
import Foundation

// Generates all viTek brand assets from the master logo & mascot images:
//   1. Apps/iOS/viTek/Assets.xcassets/AppIcon.appiconset/viTek.png (1024x1024 RGB, zero alpha)
//   2. Apps/macOS/viTek/AppIcon.icns (macOS HIG squircle icon with subtle drop shadow)
//   3. assets/brand/vitek-logo.png (512x512 squircle PNG with transparent background)
//   4. assets/brand/vitek-mascot.png (640x640 crisp mascot PNG)
//   5. Apps/Shared/BrandMascot.png (512x512 bundled mascot for macOS & iOS UI)
//   6. assets/brand/dmg-background.png (660x440) & dmg-background@2x.png (1320x880) + dmg-background.tiff (multi-res @1x/@2x)

guard CommandLine.arguments.count == 3 else {
    fputs("usage: swift scripts/make_brand_assets.swift <logo-source-image> <mascot-source-image>\n", stderr)
    exit(1)
}

let logoPath = CommandLine.arguments[1]
let mascotPath = CommandLine.arguments[2]
let fm = FileManager.default
let root = URL(fileURLWithPath: fm.currentDirectoryPath)

func loadCGImage(_ path: String) -> CGImage {
    guard let ns = NSImage(contentsOfFile: path),
          let cg = ns.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        fputs("Failed to load image: \(path)\n", stderr)
        exit(1)
    }
    return cg
}

func writePNG(_ image: CGImage, to url: URL, opaque: Bool = false) {
    try? fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let rep = NSBitmapImageRep(cgImage: image)
    if opaque {
        // Re-render into an RGB-only bitmap (no alpha channel) for App Store Connect compliance.
        let w = image.width, h = image.height
        let cs = CGColorSpaceCreateDeviceRGB()
        let info = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.noneSkipLast.rawValue
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: cs, bitmapInfo: info) else {
            exit(1)
        }
        ctx.setFillColor(CGColor(red: 0.97, green: 0.985, blue: 1.0, alpha: 1.0))
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        ctx.interpolationQuality = .high
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        guard let flat = ctx.makeImage() else { exit(1) }
        let flatRep = NSBitmapImageRep(cgImage: flat)
        guard let data = flatRep.representation(using: .png, properties: [:]) else { exit(1) }
        try! data.write(to: url)
        return
    }
    guard let data = rep.representation(using: .png, properties: [:]) else { exit(1) }
    try! data.write(to: url)
}

func render(width: Int, height: Int, opaque: Bool = false, draw: (CGContext) -> Void) -> CGImage {
    let cs = CGColorSpaceCreateDeviceRGB()
    let alpha: CGImageAlphaInfo = opaque ? .noneSkipLast : .premultipliedLast
    let info = CGBitmapInfo.byteOrder32Big.rawValue | alpha.rawValue
    guard let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: cs, bitmapInfo: info) else {
        exit(1)
    }
    ctx.interpolationQuality = .high
    draw(ctx)
    return ctx.makeImage()!
}

/// Renders a macOS Big Sur / Sequoia / Tahoe squircle icon with standard ~10% canvas inset & soft shadow.
func renderMacSquircleIcon(from source: CGImage, size: Int) -> CGImage {
    render(width: size, height: size, opaque: false) { ctx in
        let s = CGFloat(size)
        let inset = s * 0.09765625 // 100/1024 standard Apple macOS icon grid
        let rect = CGRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
        let radius = rect.width * 0.2237
        let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)

        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.014), blur: s * 0.028, color: CGColor(red: 0.02, green: 0.09, blue: 0.24, alpha: 0.22))
        ctx.addPath(path)
        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        ctx.fillPath()
        ctx.restoreGState()

        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip()
        ctx.draw(source, in: rect)
        ctx.restoreGState()

        // Crisp subtle hairline highlight rim
        ctx.saveGState()
        ctx.addPath(path)
        ctx.setStrokeColor(CGColor(red: 0.05, green: 0.25, blue: 0.65, alpha: 0.14))
        ctx.setLineWidth(max(1.0, s * 0.004))
        ctx.strokePath()
        ctx.restoreGState()
    }
}

/// Softly keys out pure near-white background pixels on the mascot so it floats naturally on light cards & DMG canvas.
func makeTransparentMascot(from source: CGImage, size: Int) -> CGImage {
    let resized = render(width: size, height: size, opaque: false) { ctx in
        ctx.draw(source, in: CGRect(x: 0, y: 0, width: size, height: size))
    }
    let w = resized.width, h = resized.height
    var pixels = [UInt8](repeating: 0, count: w * h * 4)
    let cs = CGColorSpaceCreateDeviceRGB()
    let info = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
    guard let ctx = CGContext(data: &pixels, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: cs, bitmapInfo: info) else {
        return resized
    }
    ctx.draw(resized, in: CGRect(x: 0, y: 0, width: w, height: h))

    // Flood-fill from corners so white interior details (like the mascot's face/keycap!) are 100% preserved!
    var visited = [Bool](repeating: false, count: w * h)
    var queue: [Int] = []
    queue.reserveCapacity(w * 4)

    func isNearWhite(_ idx: Int) -> Bool {
        let base = idx * 4
        let r = Int(pixels[base]), g = Int(pixels[base + 1]), b = Int(pixels[base + 2])
        let minC = min(r, min(g, b))
        let maxC = max(r, max(g, b))
        return minC >= 238 && (maxC - minC) <= 18
    }

    for x in 0..<w {
        for y in [0, h - 1] {
            let idx = y * w + x
            if !visited[idx] && isNearWhite(idx) {
                visited[idx] = true
                queue.append(idx)
            }
        }
    }
    for y in 0..<h {
        for x in [0, w - 1] {
            let idx = y * w + x
            if !visited[idx] && isNearWhite(idx) {
                visited[idx] = true
                queue.append(idx)
            }
        }
    }

    var head = 0
    while head < queue.count {
        let idx = queue[head]
        head += 1
        let base = idx * 4
        pixels[base] = 0
        pixels[base + 1] = 0
        pixels[base + 2] = 0
        pixels[base + 3] = 0

        let x = idx % w
        let y = idx / w
        if x > 0 { let n = idx - 1; if !visited[n] && isNearWhite(n) { visited[n] = true; queue.append(n) } }
        if x + 1 < w { let n = idx + 1; if !visited[n] && isNearWhite(n) { visited[n] = true; queue.append(n) } }
        if y > 0 { let n = idx - w; if !visited[n] && isNearWhite(n) { visited[n] = true; queue.append(n) } }
        if y + 1 < h { let n = idx + w; if !visited[n] && isNearWhite(n) { visited[n] = true; queue.append(n) } }
    }

    // Soft 1-pixel anti-alias fringe around removed exterior background
    for y in 1..<(h - 1) {
        for x in 1..<(w - 1) {
            let idx = y * w + x
            guard !visited[idx] else { continue }
            if visited[idx - 1] || visited[idx + 1] || visited[idx - w] || visited[idx + w] {
                let base = idx * 4
                let r = Int(pixels[base]), g = Int(pixels[base + 1]), b = Int(pixels[base + 2])
                let lum = (r + g + b) / 3
                if lum > 220 {
                    let alpha = max(0, min(255, (255 - lum) * 7))
                    let scale = Double(alpha) / 255.0
                    pixels[base] = UInt8(Double(r) * scale)
                    pixels[base + 1] = UInt8(Double(g) * scale)
                    pixels[base + 2] = UInt8(Double(b) * scale)
                    pixels[base + 3] = UInt8(alpha)
                }
            }
        }
    }

    return ctx.makeImage()!
}

/// Renders a crisp Docker / GitHub Desktop / Google-style DMG Installer background at scale 1x (660x440) or 2x (1320x880).
/// Finder icon drop coordinates (top-left origin):
///   - Left ("Cài viTek.app"):  (180, 245)
///   - Right ("Applications"):  (480, 245)
func renderDMGBackground(mascot: CGImage, logo: CGImage, scale: Int) -> CGImage {
    let w = 660 * scale
    let h = 440 * scale
    let s = CGFloat(scale)

    return render(width: w, height: h, opaque: true) { ctx in
        // Flip coordinate system to top-left origin for effortless Apple HIG layout matching Finder coordinates!
        ctx.translateBy(x: 0, y: CGFloat(h))
        ctx.scaleBy(x: s, y: -s)

        let cs = CGColorSpaceCreateDeviceRGB()

        // 1. Clean pearl-white to pale ocean-sky vertical gradient
        let bgColors = [
            CGColor(red: 0.985, green: 0.992, blue: 1.000, alpha: 1.0),
            CGColor(red: 0.945, green: 0.968, blue: 0.996, alpha: 1.0),
        ] as CFArray
        if let grad = CGGradient(colorsSpace: cs, colors: bgColors, locations: [0, 1]) {
            ctx.drawLinearGradient(grad, start: CGPoint(x: 330, y: 0), end: CGPoint(x: 330, y: 440), options: [])
        }

        // 2. Subtle radial sky glow behind header
        let glowColors = [
            CGColor(red: 0.043, green: 0.400, blue: 0.894, alpha: 0.08),
            CGColor(red: 0.043, green: 0.400, blue: 0.894, alpha: 0.0),
        ] as CFArray
        if let rad = CGGradient(colorsSpace: cs, colors: glowColors, locations: [0, 1]) {
            ctx.drawRadialGradient(rad, startCenter: CGPoint(x: 330, y: 76), startRadius: 0, endCenter: CGPoint(x: 330, y: 76), endRadius: 310, options: [])
        }

        // 3. Top Header: Mascot + Brand Wordmark + Pill Subtitle
        let headerY: CGFloat = 24
        ctx.saveGState()
        // Flip image back upright in flipped context
        ctx.translateBy(x: 38, y: headerY + 88)
        ctx.scaleBy(x: 1, y: -1)
        ctx.draw(mascot, in: CGRect(x: 0, y: 0, width: 88, height: 88))
        ctx.restoreGState()

        // Draw crisp SF Pro text using NSGraphicsContext
        let nsCtx = NSGraphicsContext(cgContext: ctx, flipped: true)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = nsCtx

        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 24, weight: .bold),
            .foregroundColor: NSColor(calibratedRed: 0.07, green: 0.13, blue: 0.24, alpha: 1.0),
        ]
        let titleStr = NSAttributedString(string: "viTek", attributes: titleAttrs)
        titleStr.draw(at: NSPoint(x: 138, y: 34))

        // Open-source pill measured dynamically so text never overflows
        let pillAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: NSColor(calibratedRed: 0.04, green: 0.36, blue: 0.82, alpha: 1.0),
        ]
        let pillStr = NSAttributedString(string: "100% Swift Native · MIT Open Source", attributes: pillAttrs)
        let pillTextSize = pillStr.size()
        let pillX = 138 + titleStr.size().width + 12
        let pillRect = CGRect(x: pillX, y: 39, width: ceil(pillTextSize.width) + 20, height: 22)
        let pillPath = CGPath(roundedRect: pillRect, cornerWidth: 11, cornerHeight: 11, transform: nil)
        ctx.addPath(pillPath)
        ctx.setFillColor(CGColor(red: 0.043, green: 0.400, blue: 0.894, alpha: 0.11))
        ctx.fillPath()
        ctx.addPath(pillPath)
        ctx.setStrokeColor(CGColor(red: 0.043, green: 0.400, blue: 0.894, alpha: 0.22))
        ctx.setLineWidth(1.0)
        ctx.strokePath()
        pillStr.draw(at: NSPoint(x: pillRect.minX + 10, y: pillRect.minY + (pillRect.height - pillTextSize.height) / 2))

        let subtitleAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .regular),
            .foregroundColor: NSColor(calibratedRed: 0.30, green: 0.36, blue: 0.46, alpha: 1.0),
        ]
        NSAttributedString(
            string: "Kéo Cài viTek vào Applications để lưu — hoặc mở trực tiếp để cài bộ gõ ngay",
            attributes: subtitleAttrs
        ).draw(at: NSPoint(x: 138, y: 70))

        // 4. Two Frosted Drop-Zone Cards (Docker / GitHub / Google aesthetic)
        // Aligned symmetrically around Finder icon positions: left (180, 245), right (480, 245)
        for centerX in [CGFloat(180), CGFloat(480)] {
            let card = CGRect(x: centerX - 96, y: 146, width: 192, height: 204)
            let cardPath = CGPath(roundedRect: card, cornerWidth: 24, cornerHeight: 24, transform: nil)

            ctx.saveGState()
            ctx.setShadow(offset: CGSize(width: 0, height: 4), blur: 16, color: CGColor(red: 0.04, green: 0.16, blue: 0.38, alpha: 0.07))
            ctx.addPath(cardPath)
            ctx.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.86))
            ctx.fillPath()
            ctx.restoreGState()

            ctx.addPath(cardPath)
            if centerX > 330 {
                ctx.setLineDash(phase: 0, lengths: [6, 5])
                ctx.setStrokeColor(CGColor(red: 0.043, green: 0.400, blue: 0.894, alpha: 0.38))
                ctx.setLineWidth(1.5)
            } else {
                ctx.setLineDash(phase: 0, lengths: [])
                ctx.setStrokeColor(CGColor(red: 0.043, green: 0.25, blue: 0.55, alpha: 0.12))
                ctx.setLineWidth(1.0)
            }
            ctx.strokePath()
        }
        ctx.setLineDash(phase: 0, lengths: [])

        // 5. Sleek Curved / Straight Vector Arrow in the Center (x = 294..366, y = 248)
        let arrowY: CGFloat = 246
        ctx.saveGState()
        ctx.setStrokeColor(CGColor(red: 0.043, green: 0.400, blue: 0.894, alpha: 0.88))
        ctx.setLineWidth(4.0)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        ctx.move(to: CGPoint(x: 298, y: arrowY))
        ctx.addLine(to: CGPoint(x: 358, y: arrowY))
        ctx.move(to: CGPoint(x: 344, y: arrowY - 13))
        ctx.addLine(to: CGPoint(x: 360, y: arrowY))
        ctx.addLine(to: CGPoint(x: 344, y: arrowY + 13))
        ctx.strokePath()
        ctx.restoreGState()

        // Subtle golden accent dot above arrow
        ctx.setFillColor(CGColor(red: 0.968, green: 0.710, blue: 0.161, alpha: 0.95))
        ctx.fillEllipse(in: CGRect(x: 325, y: arrowY - 26, width: 8, height: 8))

        let dragHintAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11.5, weight: .medium),
            .foregroundColor: NSColor(calibratedRed: 0.04, green: 0.36, blue: 0.82, alpha: 0.85),
        ]
        let dragStr = NSAttributedString(string: "Kéo thả", attributes: dragHintAttrs)
        let dragSize = dragStr.size()
        dragStr.draw(at: NSPoint(x: 330 - dragSize.width / 2, y: arrowY + 20))

        // 6. Clean Footer Guidance Bar
        let footerAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11.5, weight: .regular),
            .foregroundColor: NSColor(calibratedRed: 0.38, green: 0.44, blue: 0.54, alpha: 1.0),
        ]
        let footerStr = NSAttributedString(
            string: "Mở Cài viTek để kích hoạt bộ gõ tiếng Việt · Chọn viTek qua 🌐 hoặc ⌃ Space",
            attributes: footerAttrs
        )
        let footerSize = footerStr.size()
        footerStr.draw(at: NSPoint(x: 330 - footerSize.width / 2, y: 392))

        NSGraphicsContext.restoreGraphicsState()
    }
}

let logoCG = loadCGImage(logoPath)
let mascotRawCG = loadCGImage(mascotPath)

// 1. iOS AppIcon (1024x1024 opaque RGB PNG)
let iosIcon = render(width: 1024, height: 1024, opaque: true) { ctx in
    ctx.draw(logoCG, in: CGRect(x: 0, y: 0, width: 1024, height: 1024))
}
writePNG(iosIcon, to: root.appendingPathComponent("Apps/iOS/viTek/Assets.xcassets/AppIcon.appiconset/viTek.png"), opaque: true)

// 2. macOS AppIcon.icns via iconutil
let iconsetURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("viTek-\(UUID().uuidString).iconset")
try! fm.createDirectory(at: iconsetURL, withIntermediateDirectories: true)
defer { try? fm.removeItem(at: iconsetURL) }

let iconSpecs: [(String, Int)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024),
]
for (filename, px) in iconSpecs {
    writePNG(renderMacSquircleIcon(from: logoCG, size: px), to: iconsetURL.appendingPathComponent(filename))
}
let icnsURL = root.appendingPathComponent("Apps/macOS/viTek/AppIcon.icns")
let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconsetURL.path, "-o", icnsURL.path]
try! iconutil.run()
iconutil.waitUntilExit()
guard iconutil.terminationStatus == 0 else {
    fputs("iconutil failed\n", stderr)
    exit(1)
}

// 3. Brand Logo & Transparent Mascot PNGs (repo assets + bundled Shared resource)
writePNG(renderMacSquircleIcon(from: logoCG, size: 512), to: root.appendingPathComponent("assets/brand/vitek-logo.png"))
let mascotTransparent640 = makeTransparentMascot(from: mascotRawCG, size: 640)
writePNG(mascotTransparent640, to: root.appendingPathComponent("assets/brand/vitek-mascot.png"))
let mascotTransparent512 = makeTransparentMascot(from: mascotRawCG, size: 512)
writePNG(mascotTransparent512, to: root.appendingPathComponent("Apps/Shared/BrandMascot.png"))

// 4. Retina DMG Installer Backgrounds (@1x 660x440, @2x 1320x880, and multi-resolution TIFF for Finder)
let dmg1x = renderDMGBackground(mascot: mascotTransparent512, logo: logoCG, scale: 1)
let dmg2x = renderDMGBackground(mascot: mascotTransparent512, logo: logoCG, scale: 2)
let dmg1xURL = root.appendingPathComponent("assets/brand/dmg-background.png")
let dmg2xURL = root.appendingPathComponent("assets/brand/dmg-background@2x.png")
let dmgTiffURL = root.appendingPathComponent("assets/brand/dmg-background.tiff")
writePNG(dmg1x, to: dmg1xURL, opaque: true)
writePNG(dmg2x, to: dmg2xURL, opaque: true)

let tiffutil = Process()
tiffutil.executableURL = URL(fileURLWithPath: "/usr/bin/tiffutil")
tiffutil.arguments = ["-cathidpicheck", dmg1xURL.path, dmg2xURL.path, "-out", dmgTiffURL.path]
try! tiffutil.run()
tiffutil.waitUntilExit()
guard tiffutil.terminationStatus == 0 else {
    fputs("tiffutil failed\n", stderr)
    exit(1)
}

print("Generated all viTek brand assets, AppIcon.icns, iOS AppIcon, and retina DMG background TIFF.")
