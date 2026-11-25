// Draws the input source icon as a vector PDF template, the way macOS's own input sources ship
// theirs: the system tints it for the menu bar and rasterizes it sharp at every size and scale.
// The letters are glyph outlines cut out of the shape (even-odd fill), not rendered text. The badge
// is 22 × 16 pt, the size and corner radius macOS uses for its own input-source badges ("A", "VI").
//
//   swift scripts/make_input_icon.swift Apps/macOS/viTek/InputIconTemplate.pdf [filled|outline|u]
import AppKit
import CoreText

let arguments = Array(CommandLine.arguments.dropFirst())
let output = arguments.first ?? "InputIconTemplate.pdf"
let style = arguments.dropFirst().first ?? "filled"
let size = CGSize(width: 22, height: 16)

/// The outlines of `text` in the system font, centred on `center` by their ink, not their advance.
func glyphPath(_ text: String, size: CGFloat, weight: NSFont.Weight, center: CGPoint) -> CGPath {
    let font = NSFont.systemFont(ofSize: size, weight: weight) as CTFont
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
    let move = CGAffineTransform(translationX: center.x - ink.midX, y: center.y - ink.midY)
    return path.copy(using: [move])!
}

var box = CGRect(origin: .zero, size: size)
guard let context = CGContext(URL(fileURLWithPath: output) as CFURL, mediaBox: &box, nil) else {
    fatalError("make_input_icon: cannot write \(output)")
}
context.beginPDFPage(nil)
context.setFillColor(NSColor.black.cgColor)

let badge = CGRect(origin: .zero, size: size).insetBy(dx: 0.5, dy: 0.5)
let center = CGPoint(x: badge.midX, y: badge.midY)
switch style {
case "outline":
    let frame = badge.insetBy(dx: 0.6, dy: 0.6)
    let ring = CGMutablePath()
    ring.addPath(CGPath(roundedRect: frame, cornerWidth: 4, cornerHeight: 4, transform: nil))
    ring.addPath(CGPath(roundedRect: frame.insetBy(dx: 1.2, dy: 1.2), cornerWidth: 2.8, cornerHeight: 2.8, transform: nil))
    context.addPath(ring)
    context.fillPath(using: .evenOdd)
    context.addPath(glyphPath("Vi", size: 10.5, weight: .semibold, center: center))
    context.fillPath()
default:
    let letters = style == "u" ? "Ư" : "Vi"
    let shape = CGMutablePath()
    shape.addPath(CGPath(roundedRect: badge, cornerWidth: 4.5, cornerHeight: 4.5, transform: nil))
    shape.addPath(glyphPath(letters, size: style == "u" ? 12 : 11.5, weight: .semibold, center: center))
    context.addPath(shape)
    context.fillPath(using: .evenOdd)
}

context.endPDFPage()
context.closePDF()
print("Wrote \(output) (\(style))")
