import Foundation
import Testing
@testable import VitekEngine

@Suite struct GlyphsTests {
    /// Combining marks for each tone, in `Tone` order.
    private let toneMarks: [Unicode.Scalar?] = [nil, "\u{300}", "\u{301}", "\u{309}", "\u{303}", "\u{323}"]

    private let vowelMarks: [Mark: Unicode.Scalar] = [.circumflex: "\u{302}", .breve: "\u{306}", .horn: "\u{31B}"]

    @Test func everyGlyphIsOnePrecomposedScalar() {
        for character in Glyphs.allVietnameseCharacters {
            #expect(character.unicodeScalars.count == 1, "\(character) is not precomposed")
        }
    }

    @Test func everyGlyphDecomposesToItsLetterAndTone() {
        let bases: [UInt8] = [ASCII.a, ASCII.e, UInt8(ascii: "i"), ASCII.o, ASCII.u, ASCII.y]
        let marks: [Mark] = [.none, .circumflex, .breve, .horn]
        for base in bases {
            for mark in marks where Form(base, mark).accepts(mark) {
                for tone in Tone.allCases {
                    for uppercase in [false, true] {
                        let letter = Letter(form: Form(base, mark), isUppercase: uppercase)
                        let glyph = Glyphs.character(letter, tone: tone)
                        var expected = String(Unicode.Scalar(uppercase ? ASCII.uppercased(base) : base))
                        if let vowelMark = vowelMarks[mark] { expected.unicodeScalars.append(vowelMark) }
                        if let toneMark = toneMarks[Int(tone.rawValue)] { expected.unicodeScalars.append(toneMark) }
                        let decomposed = String(glyph).decomposedStringWithCanonicalMapping
                        // Canonical order puts the dot below before the marks above; compare as sets.
                        #expect(Set(decomposed.unicodeScalars) == Set(expected.unicodeScalars),
                                "\(glyph) ≠ \(Form(base, mark)) + \(tone)")
                        #expect(Glyphs.parse(glyph)?.letter == letter)
                        #expect(Glyphs.parse(glyph)?.tone == tone)
                    }
                }
            }
        }
    }

    @Test func dStroke() {
        #expect(Glyphs.character(Letter(form: Form("d", .stroke), isUppercase: false), tone: .level) == "đ")
        #expect(Glyphs.character(Letter(form: Form("d", .stroke), isUppercase: true), tone: .level) == "Đ")
    }
}
