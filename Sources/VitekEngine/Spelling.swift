/// Comparing words the way a Vietnamese typist builds them: letters first, marks and tones later.
public enum Spelling {
    /// Coarse dictionary index only. Always verify a match with `word(_:continues:)`:
    /// folding must never erase the accents the user explicitly typed.
    public static func lookupKey(_ text: String) -> String {
        String(text.flatMap { character -> [Character] in
            if let parsed = parse(character) {
                return [Character(Unicode.Scalar(parsed.form.base))]
            }
            return Array(character.lowercased())
        })
    }

    /// True when `word` can be what the user is typing as `prefix`. A letter typed without a mark
    /// or tone matches any marked form of it (`ngu` → người, `d` → đ); a mark or tone that was typed
    /// must be in `word` (`ngư` continues to người but not to ngủ). Case is ignored.
    public static func word(_ word: String, continues prefix: String) -> Bool {
        let candidate = Array(word)
        let typed = Array(prefix)
        guard candidate.count >= typed.count else { return false }
        for (t, c) in zip(typed, candidate) {
            guard let tl = parse(t), let cl = parse(c) else {
                if t.lowercased() != c.lowercased() { return false }
                continue
            }
            guard tl.form.base == cl.form.base else { return false }
            if tl.form.mark != .none, tl.form.mark != cl.form.mark { return false }
            if tl.tone != .level, tl.tone != cl.tone { return false }
        }
        return true
    }

    private static func parse(_ character: Character) -> (form: Form, tone: Tone)? {
        if let byte = character.asciiValue, ASCII.isLetter(byte) { return (Form(ASCII.lowercased(byte)), .level) }
        return Glyphs.parse(character).map { ($0.letter.form, $0.tone) }
    }
}
