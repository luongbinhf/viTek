// Draws the viTek app icon from vector shapes at every size macOS asks for and packs them into an
// .icns. Without an app icon, macOS shows a generic placeholder for viTek in Finder, System Settings
// and the input source pickers.
//
//   swift scripts/make_app_icon.swift Apps/macOS/viTek/AppIcon.icns [blue|key]
//
// A .png output renders the same mark on an opaque full-bleed square for the iOS app icon.
// Layout follows the macOS icon grid: a 1024 pt canvas, an 824 pt rounded body centred with a soft
// drop shadow. The letters are glyph outlines of the system font, so every size is drawn, not scaled.
import AppKit
import CoreText

let arguments = Array(CommandLine.arguments.dropFirst())
let output = arguments.first ?? "AppIcon.icns"
let style = arguments.dropFirst().first ?? "key"

func color(_ hex: UInt32) -> CGColor {
    CGColor(srgbRed: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}

/// The outlines of `text`, scaled so their ink is `height` tall and centred on `center`.
func letters(_ text: String, height: CGFloat, center: CGPoint) -> CGPath {
    let font = NSFont.systemFont(ofSize: 100, weight: .bold) as CTFont
    let characters = Array(text.utf16)
    var glyphs = [CGGlyph](repeating: 0, count: characters.count)
    CTFontGetGlyphsForCharacters(font, characters, &glyphs, characters.count)
    var advances = [CGSize](repeating: .zero, count: glyphs.count)
    CTFontGetAdvancesForGlyphs(font, .horizontal, glyphs, &advances, glyphs.count)
    let path = CGMutablePath()
    var x: CGFloat = 0
    for (glyph, advance) in zip(glyphs, advances) {
        if let outline = CTFontCreatePathForGlyph(font, glyph, nil) {
            path.addPath(outline, transform: CGAffineTransform(translationX: x, y: 0))
        }
        x += advance.width
    }
    let ink = path.boundingBoxOfPath
    let scale = height / ink.height
    var transform = CGAffineTransform(translationX: center.x, y: center.y)
        .scaledBy(x: scale, y: scale)
        .translatedBy(x: -ink.midX, y: -ink.midY)
    return path.copy(using: &transform)!
}

func render(pixels: Int) -> Data {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let mobile = output.hasSuffix(".png")
    let alpha: CGImageAlphaInfo = mobile ? .noneSkipLast : .premultipliedLast
    let context = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
                            space: space, bitmapInfo: alpha.rawValue)!
    let unit = CGFloat(pixels) / 1024
    context.scaleBy(x: unit, y: unit)

    let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    if mobile {
        context.setFillColor(color(0xFAFAFA))
        context.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))
        context.scaleBy(x: 1024 / body.width, y: 1024 / body.height)
        context.translateBy(x: -body.minX, y: -body.minY)
    }
    let shape = CGPath(roundedRect: body, cornerWidth: 185, cornerHeight: 185, transform: nil)

    context.saveGState()
    // Shadow offset and blur are in device pixels, outside the scale above.
    if !mobile { context.setShadow(offset: CGSize(width: 0, height: -10 * unit), blur: 24 * unit, color: CGColor(gray: 0, alpha: 0.28)) }
    context.addPath(shape)
    // The body's own colour, so no other colour shows at its anti-aliased edge.
    context.setFillColor(color(style == "key" ? 0xFAFAFA : 0x4A6CF7))
    context.fillPath()
    context.restoreGState()

    context.saveGState()
    context.addPath(shape)
    context.clip()
    let center = CGPoint(x: body.midX, y: body.midY)
    switch style {
    case "key":
        // A white body with one blue key on it.
        context.setFillColor(color(0xFAFAFA))
        context.fill(body)
        let key = body.insetBy(dx: 150, dy: 150)
        let keyPath = CGPath(roundedRect: key, cornerWidth: 90, cornerHeight: 90, transform: nil)
        context.addPath(keyPath)
        context.clip()
        let gradient = CGGradient(colorsSpace: space, colors: [color(0x3E8BFF), color(0x2563EB)] as CFArray, locations: [0, 1])!
        context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: key.maxY), end: CGPoint(x: 0, y: key.minY), options: [])
        context.addPath(letters("Vi", height: 250, center: CGPoint(x: key.midX, y: key.midY)))
    default:
        let gradient = CGGradient(colorsSpace: space, colors: [color(0x3E8BFF), color(0x5B4BE8)] as CFArray, locations: [0, 1])!
        context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: body.maxY), end: CGPoint(x: 0, y: body.minY), options: [])
        context.addPath(letters("Vi", height: 400, center: CGPoint(x: center.x, y: center.y - 4)))
    }
    context.setFillColor(CGColor(gray: 1, alpha: 1))
    context.fillPath()
    context.restoreGState()

    let rep = NSBitmapImageRep(cgImage: context.makeImage()!)
    return rep.representation(using: .png, properties: [:])!
}

if output.hasSuffix(".png") {
    try render(pixels: 1024).write(to: URL(fileURLWithPath: output))
    exit(0)
}

let iconset = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for points in [16, 32, 128, 256, 512] {
    try render(pixels: points).write(to: iconset.appendingPathComponent("icon_\(points)x\(points).png"))
    try render(pixels: points * 2).write(to: iconset.appendingPathComponent("icon_\(points)x\(points)@2x.png"))
}
let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", output]
try iconutil.run()
iconutil.waitUntilExit()
guard iconutil.terminationStatus == 0 else { fatalError("make_app_icon: iconutil failed") }
print("Wrote \(output) (\(style))")
