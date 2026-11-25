/// Precomposed (NFC) characters for every Vietnamese letter and tone, and the reverse lookup.
enum Glyphs {
    private struct Row: Sendable {
        let form: Form
        /// Indexed by `Tone.rawValue`: level, grave, acute, hook, tilde, dot.
        let lower: [Character]
        let upper: [Character]
    }

    private static let rows: [Row] = [
        Row(form: Form("a"), lower: Array("aàáảãạ"), upper: Array("AÀÁẢÃẠ")),
        Row(form: Form("a", .breve), lower: Array("ăằắẳẵặ"), upper: Array("ĂẰẮẲẴẶ")),
        Row(form: Form("a", .circumflex), lower: Array("âầấẩẫậ"), upper: Array("ÂẦẤẨẪẬ")),
        Row(form: Form("e"), lower: Array("eèéẻẽẹ"), upper: Array("EÈÉẺẼẸ")),
        Row(form: Form("e", .circumflex), lower: Array("êềếểễệ"), upper: Array("ÊỀẾỂỄỆ")),
        Row(form: Form("i"), lower: Array("iìíỉĩị"), upper: Array("IÌÍỈĨỊ")),
        Row(form: Form("o"), lower: Array("oòóỏõọ"), upper: Array("OÒÓỎÕỌ")),
        Row(form: Form("o", .circumflex), lower: Array("ôồốổỗộ"), upper: Array("ÔỒỐỔỖỘ")),
        Row(form: Form("o", .horn), lower: Array("ơờớởỡợ"), upper: Array("ƠỜỚỞỠỢ")),
        Row(form: Form("u"), lower: Array("uùúủũụ"), upper: Array("UÙÚỦŨỤ")),
        Row(form: Form("u", .horn), lower: Array("ưừứửữự"), upper: Array("ƯỪỨỬỮỰ")),
        Row(form: Form("y"), lower: Array("yỳýỷỹỵ"), upper: Array("YỲÝỶỸỴ")),
    ]

    private static let stroke = Form("d", .stroke)

    private static let byForm: [Form: Row] = Dictionary(uniqueKeysWithValues: rows.map { ($0.form, $0) })

    private static let parsed: [Character: (letter: Letter, tone: Tone)] = {
        var table: [Character: (letter: Letter, tone: Tone)] = [:]
        for row in rows {
            for tone in Tone.allCases {
                let index = Int(tone.rawValue)
                table[row.lower[index]] = (Letter(form: row.form, isUppercase: false), tone)
                table[row.upper[index]] = (Letter(form: row.form, isUppercase: true), tone)
            }
        }
        table["đ"] = (Letter(form: stroke, isUppercase: false), .level)
        table["Đ"] = (Letter(form: stroke, isUppercase: true), .level)
        return table
    }()

    /// Every Vietnamese-specific character this table knows, for tests and tools.
    static var allVietnameseCharacters: [Character] { Array(parsed.keys) }

    static func character(_ letter: Letter, tone: Tone) -> Character {
        if let row = byForm[letter.form] {
            return (letter.isUppercase ? row.upper : row.lower)[Int(tone.rawValue)]
        }
        if letter.form == stroke {
            return letter.isUppercase ? "Đ" : "đ"
        }
        let base = letter.isUppercase ? ASCII.uppercased(letter.form.base) : letter.form.base
        return Character(Unicode.Scalar(base))
    }

    /// The letter and tone a precomposed Vietnamese character stands for (`ệ` → ê + dot).
    /// ASCII letters are not in the table; callers handle them directly.
    static func parse(_ character: Character) -> (letter: Letter, tone: Tone)? {
        parsed[character]
    }
}
