/// Pure-Swift Vietnamese character set and diacritic conversions.
///
/// Uses only the Swift standard library (`Unicode.Scalar` tables) so it runs identically inside
/// `VitekSession`, InputMethodKit, iOS Keyboard Extensions, and Apple Shortcuts without Foundation.
public enum TextConverter {
    public enum LegacyEncoding: String, Sendable, CaseIterable {
        case autoToUnicode
        case nfdToNFC
        case stripAccents
        case vniWindows
        case tcvn3
        case uppercase
        case lowercase
        case titleCase
    }

    public static func convert(_ text: String, mode: LegacyEncoding) -> String {
        switch mode {
        case .autoToUnicode: autoConvertToUnicode(text)
        case .nfdToNFC: normalizeNFC(text)
        case .stripAccents: stripVietnameseAccents(text)
        case .vniWindows: convertVNIWindowsToUnicode(text)
        case .tcvn3: convertTCVN3ToUnicode(text)
        case .uppercase: uppercaseVietnamese(text)
        case .lowercase: lowercaseVietnamese(text)
        case .titleCase: titleCaseVietnamese(text)
        }
    }

    // MARK: - Unicode NFC Normalization (NFD / CP1258 -> Precomposed NFC)

    private enum VowelShape: Int {
        case plain = 0
        case breve = 1      // ă
        case circumflex = 2 // â, ê, ô
        case horn = 3       // ơ, ư
    }

    private enum ToneMark: Int {
        case level = 0
        case grave = 1 // à
        case acute = 2 // á
        case hook = 3  // ả
        case tilde = 4 // ã
        case dot = 5   // ạ
    }

    private struct VowelEntry: Hashable {
        let base: UInt8
        let shape: VowelShape
    }

    private struct DecodedVowel {
        var base: UInt8
        var isUpper: Bool
        var shape: VowelShape
        var tone: ToneMark
    }

    private static let rows: [(entry: VowelEntry, lower: [Unicode.Scalar], upper: [Unicode.Scalar])] = [
        (VowelEntry(base: UInt8(ascii: "a"), shape: .plain), Array("aàáảãạ".unicodeScalars), Array("AÀÁẢÃẠ".unicodeScalars)),
        (VowelEntry(base: UInt8(ascii: "a"), shape: .breve), Array("ăằắẳẵặ".unicodeScalars), Array("ĂẰẮẲẴẶ".unicodeScalars)),
        (VowelEntry(base: UInt8(ascii: "a"), shape: .circumflex), Array("âầấẩẫậ".unicodeScalars), Array("ÂẦẤẨẪẬ".unicodeScalars)),
        (VowelEntry(base: UInt8(ascii: "e"), shape: .plain), Array("eèéẻẽẹ".unicodeScalars), Array("EÈÉẺẼẸ".unicodeScalars)),
        (VowelEntry(base: UInt8(ascii: "e"), shape: .circumflex), Array("êềếểễệ".unicodeScalars), Array("ÊỀẾỂỄỆ".unicodeScalars)),
        (VowelEntry(base: UInt8(ascii: "i"), shape: .plain), Array("iìíỉĩị".unicodeScalars), Array("IÌÍỈĨỊ".unicodeScalars)),
        (VowelEntry(base: UInt8(ascii: "o"), shape: .plain), Array("oòóỏõọ".unicodeScalars), Array("OÒÓỎÕỌ".unicodeScalars)),
        (VowelEntry(base: UInt8(ascii: "o"), shape: .circumflex), Array("ôồốổỗộ".unicodeScalars), Array("ÔỒỐỔỖỘ".unicodeScalars)),
        (VowelEntry(base: UInt8(ascii: "o"), shape: .horn), Array("ơờớởỡợ".unicodeScalars), Array("ƠỜỚỞỠỢ".unicodeScalars)),
        (VowelEntry(base: UInt8(ascii: "u"), shape: .plain), Array("uùúủũụ".unicodeScalars), Array("UÙÚỦŨỤ".unicodeScalars)),
        (VowelEntry(base: UInt8(ascii: "u"), shape: .horn), Array("ưừứửữự".unicodeScalars), Array("ƯỪỨỬỮỰ".unicodeScalars)),
        (VowelEntry(base: UInt8(ascii: "y"), shape: .plain), Array("yỳýỷỹỵ".unicodeScalars), Array("YỲÝỶỸỴ".unicodeScalars)),
    ]

    private static let composeTable: [VowelEntry: (lower: [Unicode.Scalar], upper: [Unicode.Scalar])] = {
        var map: [VowelEntry: (lower: [Unicode.Scalar], upper: [Unicode.Scalar])] = [:]
        for row in rows {
            map[row.entry] = (row.lower, row.upper)
        }
        return map
    }()

    private static let decodeTable: [Unicode.Scalar: DecodedVowel] = {
        var map: [Unicode.Scalar: DecodedVowel] = [:]
        let tones: [ToneMark] = [.level, .grave, .acute, .hook, .tilde, .dot]
        for row in rows {
            for (idx, tone) in tones.enumerated() {
                map[row.lower[idx]] = DecodedVowel(base: row.entry.base, isUpper: false, shape: row.entry.shape, tone: tone)
                map[row.upper[idx]] = DecodedVowel(base: row.entry.base, isUpper: true, shape: row.entry.shape, tone: tone)
            }
        }
        return map
    }()

    /// Composes decomposed Vietnamese combining sequences (NFD and Windows-1258) into single
    /// precomposed Unicode NFC scalars. Leaves all non-Vietnamese characters and Emoji untouched.
    public static func normalizeNFC(_ text: String) -> String {
        guard !text.isEmpty else { return "" }
        let scalars = text.unicodeScalars
        var out = String.UnicodeScalarView()
        out.reserveCapacity(scalars.count)

        var index = scalars.startIndex
        while index < scalars.endIndex {
            let scalar = scalars[index]
            index = scalars.index(after: index)

            if scalar == "d" || scalar == "D",
               index < scalars.endIndex,
               scalars[index] == "\u{0335}" || scalars[index] == "\u{0336}" {
                out.append(scalar == "D" ? "Đ" : "đ")
                index = scalars.index(after: index)
                continue
            }

            guard var vowel = decodeTable[scalar] else {
                out.append(scalar)
                continue
            }

            while index < scalars.endIndex {
                let next = scalars[index]
                if let shape = combiningShape(next), vowel.shape == .plain, accepts(base: vowel.base, shape: shape) {
                    vowel.shape = shape
                    index = scalars.index(after: index)
                } else if let tone = combiningTone(next), vowel.tone == .level {
                    vowel.tone = tone
                    index = scalars.index(after: index)
                } else {
                    break
                }
            }

            let key = VowelEntry(base: vowel.base, shape: vowel.shape)
            if let composed = composeTable[key] {
                out.append((vowel.isUpper ? composed.upper : composed.lower)[vowel.tone.rawValue])
            } else {
                out.append(scalar)
            }
        }
        return String(out)
    }

    private static func combiningShape(_ scalar: Unicode.Scalar) -> VowelShape? {
        switch scalar {
        case "\u{0306}": .breve
        case "\u{0302}": .circumflex
        case "\u{031B}": .horn
        default: nil
        }
    }

    private static func combiningTone(_ scalar: Unicode.Scalar) -> ToneMark? {
        switch scalar {
        case "\u{0300}": .grave
        case "\u{0301}": .acute
        case "\u{0309}": .hook
        case "\u{0303}": .tilde
        case "\u{0323}": .dot
        default: nil
        }
    }

    private static func accepts(base: UInt8, shape: VowelShape) -> Bool {
        switch shape {
        case .plain: true
        case .breve: base == UInt8(ascii: "a")
        case .circumflex: base == UInt8(ascii: "a") || base == UInt8(ascii: "e") || base == UInt8(ascii: "o")
        case .horn: base == UInt8(ascii: "o") || base == UInt8(ascii: "u")
        }
    }

    // MARK: - Strip Vietnamese Accents

    /// Removes all Vietnamese vowel marks, tone marks, and `đ`/`Đ` strokes while preserving case.
    public static func stripVietnameseAccents(_ text: String) -> String {
        guard !text.isEmpty else { return "" }
        let normalized = normalizeNFC(text)
        var out = String.UnicodeScalarView()
        out.reserveCapacity(normalized.unicodeScalars.count)
        for scalar in normalized.unicodeScalars {
            if let vowel = decodeTable[scalar] {
                let ascii = vowel.isUpper ? (vowel.base &- 32) : vowel.base
                out.append(Unicode.Scalar(ascii))
            } else if scalar == "đ" || scalar == "\u{00F0}" {
                out.append("d")
            } else if scalar == "Đ" || scalar == "\u{00D0}" {
                out.append("D")
            } else if combiningShape(scalar) != nil || combiningTone(scalar) != nil {
                continue
            } else {
                out.append(scalar)
            }
        }
        return String(out)
    }

    // MARK: - VNI Windows -> Unicode NFC

    private static let vniStandalone: [UInt32: Unicode.Scalar] = [
        0xC6: "Ỉ", 0xE6: "ỉ",
        0xCC: "Ì", 0xEC: "ì",
        0xCD: "Í", 0xED: "í",
        0xCE: "Ỵ", 0xEE: "ỵ",
        0xD1: "Đ", 0xF1: "đ",
        0xD2: "Ị", 0xF2: "ị",
        0xD3: "Ĩ", 0xF3: "ĩ",
        0xD4: "Ơ", 0xF4: "ơ",
        0xD6: "Ư", 0xF6: "ư",
    ]

    private static let vniCombining: [UInt32: [Unicode.Scalar]] = [
        0xC0: ["\u{0302}", "\u{0300}"], 0xE0: ["\u{0302}", "\u{0300}"],
        0xC1: ["\u{0302}", "\u{0301}"], 0xE1: ["\u{0302}", "\u{0301}"],
        0xC2: ["\u{0302}"],             0xE2: ["\u{0302}"],
        0xC3: ["\u{0302}", "\u{0303}"], 0xE3: ["\u{0302}", "\u{0303}"],
        0xC4: ["\u{0302}", "\u{0323}"], 0xE4: ["\u{0302}", "\u{0323}"],
        0xC5: ["\u{0302}", "\u{0309}"], 0xE5: ["\u{0302}", "\u{0309}"],
        0xC8: ["\u{0306}", "\u{0300}"], 0xE8: ["\u{0306}", "\u{0300}"],
        0xC9: ["\u{0306}", "\u{0301}"], 0xE9: ["\u{0306}", "\u{0301}"],
        0xCA: ["\u{0306}"],             0xEA: ["\u{0306}"],
        0xCB: ["\u{0306}", "\u{0323}"], 0xEB: ["\u{0306}", "\u{0323}"],
        0xCF: ["\u{0323}"],             0xEF: ["\u{0323}"],
        0xD5: ["\u{0303}"],             0xF5: ["\u{0303}"],
        0xD8: ["\u{0300}"],             0xF8: ["\u{0300}"],
        0xD9: ["\u{0301}"],             0xF9: ["\u{0301}"],
        0xDA: ["\u{0306}", "\u{0309}"], 0xFA: ["\u{0306}", "\u{0309}"],
        0xDB: ["\u{0309}"],             0xFB: ["\u{0309}"],
        0xDC: ["\u{0306}", "\u{0303}"], 0xFC: ["\u{0306}", "\u{0303}"],
    ]

    /// Converts legacy 2-byte VNI-Windows (`VNI-Times`, `VNI-Helve`) text into precomposed Unicode NFC.
    public static func convertVNIWindowsToUnicode(_ text: String) -> String {
        guard !text.isEmpty else { return "" }
        var intermediate = String.UnicodeScalarView()
        intermediate.reserveCapacity(text.unicodeScalars.count)
        var lastWasCarrierVowel = false

        for scalar in text.unicodeScalars {
            let code = scalar.value
            if lastWasCarrierVowel, let marks = vniCombining[code] {
                for mark in marks { intermediate.append(mark) }
                lastWasCarrierVowel = false
                continue
            }
            if let mapped = vniStandalone[code] {
                intermediate.append(mapped)
                lastWasCarrierVowel = mapped == "Ơ" || mapped == "ơ" || mapped == "Ư" || mapped == "ư"
                continue
            }
            intermediate.append(scalar)
            lastWasCarrierVowel = isASCIIVowelExcludingI(code)
        }
        return normalizeNFC(String(intermediate))
    }

    private static func isASCIIVowelExcludingI(_ code: UInt32) -> Bool {
        switch code {
        case 0x41, 0x61, 0x45, 0x65, 0x4F, 0x6F, 0x55, 0x75, 0x59, 0x79: true
        default: false
        }
    }

    // MARK: - TCVN3 (ABC / .VnTime) -> Unicode NFC

    private static let tcvn3Table: [UInt32: Unicode.Scalar] = [
        0xA1: "Ă", 0xA2: "Â", 0xA3: "Ê", 0xA4: "Ô", 0xA5: "Ơ", 0xA6: "Ư", 0xA7: "Đ",
        0xA8: "ă", 0xA9: "â", 0xAA: "ê", 0xAB: "ô", 0xAC: "ơ", 0xAD: "ư", 0xAE: "đ",
        0xB5: "à", 0xB6: "ả", 0xB7: "ã", 0xB8: "á", 0xB9: "ạ",
        0xBB: "ằ", 0xBC: "ẳ", 0xBD: "ẵ", 0xBE: "ắ", 0xC6: "ặ",
        0xC7: "ầ", 0xC8: "ẩ", 0xC9: "ẫ", 0xCA: "ấ", 0xCB: "ậ",
        0xCC: "è", 0xCE: "ẻ", 0xCF: "ẽ", 0xD0: "é", 0xD1: "ẹ",
        0xD2: "ề", 0xD3: "ể", 0xD4: "ễ", 0xD5: "ế", 0xD6: "ệ",
        0xD7: "ì", 0xD8: "ỉ", 0xDC: "ĩ", 0xDD: "í", 0xDE: "ị",
        0xDF: "ò", 0xE1: "ỏ", 0xE2: "õ", 0xE3: "ó", 0xE4: "ọ",
        0xE5: "ồ", 0xE6: "ổ", 0xE7: "ỗ", 0xE8: "ố", 0xE9: "ộ",
        0xEA: "ờ", 0xEB: "ở", 0xEC: "ỡ", 0xED: "ớ", 0xEE: "ợ",
        0xEF: "ù", 0xF1: "ủ", 0xF2: "ũ", 0xF3: "ú", 0xF4: "ụ",
        0xF5: "ừ", 0xF6: "ử", 0xF7: "ữ", 0xF8: "ứ", 0xF9: "ự",
        0xFA: "ỳ", 0xFB: "ỷ", 0xFC: "ỹ", 0xFD: "ý", 0xFE: "ỵ",
    ]

    /// Converts legacy 1-byte TCVN3 / ABC (`.VnTime`, `.VnArial`) text into precomposed Unicode NFC.
    public static func convertTCVN3ToUnicode(_ text: String) -> String {
        guard !text.isEmpty else { return "" }
        var out = String.UnicodeScalarView()
        out.reserveCapacity(text.unicodeScalars.count)
        for scalar in text.unicodeScalars {
            if let mapped = tcvn3Table[scalar.value] {
                out.append(mapped)
            } else {
                out.append(scalar)
            }
        }
        return String(out)
    }

    // MARK: - Auto-Detect Legacy Encoding -> Unicode NFC

    /// Automatically detects VNI-Windows, TCVN3 (`.VnTime`), or decomposed Unicode NFD/CP1258
    /// and converts the text to clean precomposed Unicode NFC.
    public static func autoConvertToUnicode(_ text: String) -> String {
        guard !text.isEmpty else { return "" }
        var vniScore = 0
        var tcvnScore = 0
        var prevCode: UInt32 = 0

        for scalar in text.unicodeScalars {
            let code = scalar.value
            let prevWasCarrier = isASCIIVowelExcludingI(prevCode)
                || prevCode == 0xD4 || prevCode == 0xF4 || prevCode == 0xD6 || prevCode == 0xF6
            if prevWasCarrier, vniCombining[code] != nil {
                vniScore += 3
            } else if (code == 0xD1 || code == 0xF1), (prevCode == 0 || prevCode == 0x20 || prevCode == 0x0A) {
                vniScore += 2
            } else if (0xA1...0xBE).contains(code), tcvn3Table[code] != nil {
                tcvnScore += 3
            } else if tcvn3Table[code] != nil, isASCIIConsonant(prevCode) {
                tcvnScore += 2
            }
            prevCode = code
        }

        if vniScore > 0 && vniScore >= tcvnScore {
            return convertVNIWindowsToUnicode(text)
        }
        if tcvnScore > 0 {
            return convertTCVN3ToUnicode(text)
        }
        return normalizeNFC(text)
    }

    private static func isASCIIConsonant(_ code: UInt32) -> Bool {
        let lower = (0x41...0x5A).contains(code) ? (code | 0x20) : code
        guard (0x61...0x7A).contains(lower) else { return false }
        return !isASCIIVowelExcludingI(lower) && lower != 0x69
    }

    // MARK: - Vietnamese Case Conversions

    /// Converts all ASCII and Vietnamese letters (including `ă`, `â`, `đ`, `ê`, `ô`, `ơ`, `ư` and tones) to uppercase NFC.
    public static func uppercaseVietnamese(_ text: String) -> String {
        guard !text.isEmpty else { return "" }
        let normalized = normalizeNFC(text)
        var out = String.UnicodeScalarView()
        out.reserveCapacity(normalized.unicodeScalars.count)
        for scalar in normalized.unicodeScalars {
            out.append(upperScalar(scalar))
        }
        return String(out)
    }

    /// Converts all ASCII and Vietnamese letters to lowercase NFC.
    public static func lowercaseVietnamese(_ text: String) -> String {
        guard !text.isEmpty else { return "" }
        let normalized = normalizeNFC(text)
        var out = String.UnicodeScalarView()
        out.reserveCapacity(normalized.unicodeScalars.count)
        for scalar in normalized.unicodeScalars {
            out.append(lowerScalar(scalar))
        }
        return String(out)
    }

    /// Capitalizes the first letter of each word while lowercasing remaining letters in NFC.
    public static func titleCaseVietnamese(_ text: String) -> String {
        guard !text.isEmpty else { return "" }
        let normalized = normalizeNFC(text)
        var out = String.UnicodeScalarView()
        out.reserveCapacity(normalized.unicodeScalars.count)
        var startOfWord = true
        for scalar in normalized.unicodeScalars {
            if isWordLetter(scalar) {
                out.append(startOfWord ? upperScalar(scalar) : lowerScalar(scalar))
                startOfWord = false
            } else {
                out.append(scalar)
                if scalar == " " || scalar == "\t" || scalar == "\n" || scalar == "\r" || scalar == "-" || scalar == "/" {
                    startOfWord = true
                }
            }
        }
        return String(out)
    }

    private static func isWordLetter(_ scalar: Unicode.Scalar) -> Bool {
        if (0x41...0x5A).contains(scalar.value) || (0x61...0x7A).contains(scalar.value) { return true }
        if scalar == "đ" || scalar == "Đ" { return true }
        return decodeTable[scalar] != nil
    }

    private static func upperScalar(_ scalar: Unicode.Scalar) -> Unicode.Scalar {
        if (0x61...0x7A).contains(scalar.value), let up = Unicode.Scalar(scalar.value &- 32) {
            return up
        }
        if scalar == "đ" { return "Đ" }
        if let vowel = decodeTable[scalar], !vowel.isUpper,
           let composed = composeTable[VowelEntry(base: vowel.base, shape: vowel.shape)] {
            return composed.upper[vowel.tone.rawValue]
        }
        return scalar
    }

    private static func lowerScalar(_ scalar: Unicode.Scalar) -> Unicode.Scalar {
        if (0x41...0x5A).contains(scalar.value), let lo = Unicode.Scalar(scalar.value &+ 32) {
            return lo
        }
        if scalar == "Đ" { return "đ" }
        if let vowel = decodeTable[scalar], vowel.isUpper,
           let composed = composeTable[VowelEntry(base: vowel.base, shape: vowel.shape)] {
            return composed.lower[vowel.tone.rawValue]
        }
        return scalar
    }
}
