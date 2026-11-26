#!/usr/bin/env swift
import AppKit
import CoreGraphics
import Foundation

// Renders minimal, Apple-style App Store marketing screenshots (zero alpha PNG)
// from raw Simulator captures at exact App Store Connect resolutions:
//   - iPhone 6.9"  (iPhone 18 Pro Max): 1320 x 2868
//   - iPad Pro 13" (M5):                2064 x 2752

struct SlideSpec {
    let filename: String
    let badge: String
    let title: String
    let subtitle: String
    let topColor: NSColor
    let bottomColor: NSColor
    let accentColor: NSColor
}

let slides: [SlideSpec] = [
    SlideSpec(
        filename: "01_keyboard.png",
        badge: "LIQUID GLASS · 120HZ",
        title: "Gõ Tiếng Việt Mượt Mà",
        subtitle: "Tự nhận Telex & VNI · Không cần Truy cập đầy đủ",
        topColor: NSColor(calibratedRed: 0.05, green: 0.14, blue: 0.34, alpha: 1),
        bottomColor: NSColor(calibratedRed: 0.09, green: 0.36, blue: 0.68, alpha: 1),
        accentColor: NSColor(calibratedRed: 0.45, green: 0.82, blue: 1.0, alpha: 1)
    ),
    SlideSpec(
        filename: "02_home.png",
        badge: "100% SWIFT 6 NATIVE",
        title: "Thiết Kế Tối Giản & Riêng Tư",
        subtitle: "Xử lý hoàn toàn trên thiết bị · Mở lên dùng ngay",
        topColor: NSColor(calibratedRed: 0.08, green: 0.22, blue: 0.42, alpha: 1),
        bottomColor: NSColor(calibratedRed: 0.14, green: 0.48, blue: 0.72, alpha: 1),
        accentColor: NSColor(calibratedRed: 0.56, green: 0.88, blue: 1.0, alpha: 1)
    ),
    SlideSpec(
        filename: "03_writing.png",
        badge: "APPLE INTELLIGENCE",
        title: "Trợ Lý Viết Tiếng Việt Cục Bộ",
        subtitle: "Khôi phục dấu · Sửa lỗi chính tả & diễn đạt tự nhiên",
        topColor: NSColor(calibratedRed: 0.16, green: 0.11, blue: 0.38, alpha: 1),
        bottomColor: NSColor(calibratedRed: 0.32, green: 0.22, blue: 0.66, alpha: 1),
        accentColor: NSColor(calibratedRed: 0.78, green: 0.68, blue: 1.0, alpha: 1)
    ),
    SlideSpec(
        filename: "04_clipboard.png",
        badge: "ĐỒNG BỘ ICLOUD",
        title: "Clipboard & Mẫu Ghim Thông Minh",
        subtitle: "Tìm không dấu · Đồng bộ tức thì giữa iPhone, iPad & Mac",
        topColor: NSColor(calibratedRed: 0.04, green: 0.24, blue: 0.30, alpha: 1),
        bottomColor: NSColor(calibratedRed: 0.08, green: 0.48, blue: 0.56, alpha: 1),
        accentColor: NSColor(calibratedRed: 0.50, green: 0.94, blue: 0.88, alpha: 1)
    ),
    SlideSpec(
        filename: "05_settings.png",
        badge: "TUỲ BIẾN LINH HOẠT",
        title: "Chống Đảo Phím & Gõ Lướt",
        subtitle: "Kiểu dấu mới/cũ · Gõ tắt động · Bảo vệ từ tiếng Anh",
        topColor: NSColor(calibratedRed: 0.11, green: 0.15, blue: 0.24, alpha: 1),
        bottomColor: NSColor(calibratedRed: 0.21, green: 0.30, blue: 0.46, alpha: 1),
        accentColor: NSColor(calibratedRed: 0.64, green: 0.80, blue: 1.0, alpha: 1)
    ),
]

func renderFramed(rawURL: URL, outputURL: URL, spec: SlideSpec, isPad: Bool) throws {
    guard let srcImage = NSImage(contentsOf: rawURL),
          let cgSource = srcImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        throw NSError(domain: "FrameScreenshots", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to load \(rawURL.path)"])
    }

    let canvasW = isPad ? 2064 : 1320
    let canvasH = isPad ? 2752 : 2868

    guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
          let ctx = CGContext(
            data: nil,
            width: canvasW,
            height: canvasH,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
          ) else {
        throw NSError(domain: "FrameScreenshots", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create CGContext"])
    }

    let width = CGFloat(canvasW)
    let height = CGFloat(canvasH)

    // 1. Background vertical gradient
    let gradColors = [spec.bottomColor.cgColor, spec.topColor.cgColor] as CFArray
    if let gradient = CGGradient(colorsSpace: colorSpace, colors: gradColors, locations: [0.0, 1.0]) {
        ctx.drawLinearGradient(
            gradient,
            start: CGPoint(x: width / 2, y: 0),
            end: CGPoint(x: width / 2, y: height),
            options: []
        )
    }

    // 2. Subtle ambient Liquid Glass glow orb behind headline
    ctx.saveGState()
    let orbColors = [
        spec.accentColor.withAlphaComponent(0.24).cgColor,
        spec.accentColor.withAlphaComponent(0.0).cgColor,
    ] as CFArray
    if let orbGrad = CGGradient(colorsSpace: colorSpace, colors: orbColors, locations: [0.0, 1.0]) {
        let center = CGPoint(x: width * 0.5, y: height * 0.86)
        ctx.drawRadialGradient(
            orbGrad,
            startCenter: center,
            startRadius: 0,
            endCenter: center,
            endRadius: width * 0.65,
            options: [.drawsBeforeStartLocation]
        )
    }
    ctx.restoreGState()

    // 3. Draw AppKit typography (flipped coordinates)
    let nsCtx = NSGraphicsContext(cgContext: ctx, flipped: false)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = nsCtx

    let padX: CGFloat = isPad ? 140 : 92
    let textW = width - padX * 2

    let badgeFont = NSFont.systemFont(ofSize: isPad ? 32 : 27, weight: .bold)
    let titleFont = NSFont.systemFont(ofSize: isPad ? 88 : 74, weight: .bold)
    let subFont = NSFont.systemFont(ofSize: isPad ? 42 : 36, weight: .medium)

    let centerPara = NSMutableParagraphStyle()
    centerPara.alignment = .center
    centerPara.lineSpacing = isPad ? 10 : 8

    let badgeAttr: [NSAttributedString.Key: Any] = [
        .font: badgeFont,
        .foregroundColor: spec.accentColor,
        .paragraphStyle: centerPara,
        .kern: 2.2,
    ]
    let titleAttr: [NSAttributedString.Key: Any] = [
        .font: titleFont,
        .foregroundColor: NSColor.white,
        .paragraphStyle: centerPara,
    ]
    let subAttr: [NSAttributedString.Key: Any] = [
        .font: subFont,
        .foregroundColor: NSColor.white.withAlphaComponent(0.84),
        .paragraphStyle: centerPara,
    ]

    let badgeY = height - (isPad ? 175 : 195)
    NSAttributedString(string: spec.badge, attributes: badgeAttr)
        .draw(in: CGRect(x: padX, y: badgeY, width: textW, height: 60))

    let titleRect = CGRect(x: padX, y: badgeY - (isPad ? 150 : 190), width: textW, height: isPad ? 130 : 180)
    NSAttributedString(string: spec.title, attributes: titleAttr).draw(in: titleRect)

    let subRect = CGRect(x: padX, y: titleRect.minY - (isPad ? 95 : 120), width: textW, height: 110)
    NSAttributedString(string: spec.subtitle, attributes: subAttr).draw(in: subRect)

    NSGraphicsContext.restoreGraphicsState()

    // 4. Draw framed device screenshot with soft shadow & crisp Liquid Glass bezel
    let srcAspect = CGFloat(cgSource.width) / CGFloat(cgSource.height)
    let topMargin: CGFloat = isPad ? 470 : 570
    let bottomBleed: CGFloat = isPad ? 90 : 80
    let maxFrameH = height - topMargin - bottomBleed
    let maxFrameW = width - (isPad ? 220 : 148)

    var drawW = maxFrameW
    var drawH = drawW / srcAspect
    if drawH > maxFrameH {
        drawH = maxFrameH
        drawW = drawH * srcAspect
    }

    let frameX = (width - drawW) / 2
    let frameY = bottomBleed + (maxFrameH - drawH) * 0.45
    let deviceRect = CGRect(x: frameX, y: frameY, width: drawW, height: drawH)
    let cornerRadius: CGFloat = isPad ? 52 : 76

    // Outer shadow
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -24), blur: 64, color: NSColor.black.withAlphaComponent(0.42).cgColor)
    let outerPath = CGPath(roundedRect: deviceRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
    ctx.addPath(outerPath)
    ctx.setFillColor(NSColor.black.cgColor)
    ctx.fillPath()
    ctx.restoreGState()

    // Clipped screenshot
    ctx.saveGState()
    ctx.addPath(outerPath)
    ctx.clip()
    ctx.interpolationQuality = .high
    ctx.draw(cgSource, in: deviceRect)
    ctx.restoreGState()

    // Subtle specular Liquid Glass border
    ctx.saveGState()
    ctx.addPath(outerPath)
    ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.28).cgColor)
    ctx.setLineWidth(isPad ? 4 : 3.5)
    ctx.strokePath()
    ctx.restoreGState()

    guard let finalCG = ctx.makeImage() else {
        throw NSError(domain: "FrameScreenshots", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to create output CGImage"])
    }
    let bitmap = NSBitmapImageRep(cgImage: finalCG)
    guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "FrameScreenshots", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to encode PNG"])
    }
    try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try pngData.write(to: outputURL)
}

guard CommandLine.arguments.count == 4 else {
    fputs("Usage: frame_appstore_screenshots.swift <iphone|ipad> <raw_dir> <framed_dir>\n", stderr)
    exit(2)
}

let deviceKind = CommandLine.arguments[1].lowercased()
let isPad = (deviceKind == "ipad")
let rawDir = URL(fileURLWithPath: CommandLine.arguments[2])
let framedDir = URL(fileURLWithPath: CommandLine.arguments[3])

for spec in slides {
    let rawFile = rawDir.appendingPathComponent(spec.filename)
    guard FileManager.default.fileExists(atPath: rawFile.path) else {
        fputs("Skipping missing \(rawFile.path)\n", stderr)
        continue
    }
    let outFile = framedDir.appendingPathComponent(spec.filename)
    try renderFramed(rawURL: rawFile, outputURL: outFile, spec: spec, isPad: isPad)
    print("✓ Framed \(deviceKind): \(outFile.lastPathComponent)")
}
