import VitekEngine

/// Cleans up word suggestions from a language model for showing to the user.
public enum Suggestions {
    /// Keeps candidates that are single words continuing `prefix` in the Vietnamese sense
    /// (`Spelling.word(_:continues:)`; all of them when `prefix` is empty), without repeats or the
    /// prefix itself, at most `limit`. A capitalised prefix capitalises the suggestions;
    /// an uppercase prefix of two or more letters keeps uppercase typing. A lowercase prefix
    /// keeps the model's spelling (`Nguyen`). Technical tokens such as UTF-8 are allowed.
    public static func prepare(_ candidates: [String], prefix: String, limit: Int = 5) -> [String] {
        guard limit > 0 else { return [] }
        let lowerPrefix = prefix.lowercased()
        let capitalise = prefix.first?.isUppercase == true
        let uppercase = prefix.count > 1 && prefix != lowerPrefix && prefix == prefix.uppercased()
        var seen = Set<String>()
        var result: [String] = []
        for raw in candidates {
            let word = raw.trimmingWhitespace()
            guard isToken(word), Spelling.word(word, continues: prefix),
                  word.lowercased() != lowerPrefix
            else { continue }
            let shown = uppercase ? word.uppercased() : (capitalise ? word.prefix(1).uppercased() + word.dropFirst() : word)
            guard seen.insert(shown.lowercased()).inserted else { continue }
            result.append(shown)
            if result.count == limit { break }
        }
        return result
    }

    /// Letters (including decomposed accents), digits and common technical-token separators.
    /// Scalar validation also rejects invisible format/control characters inside a grapheme.
    static func isToken(_ word: String) -> Bool {
        guard word.first?.isLetter == true, word.count <= 80 else { return false }
        return word.unicodeScalars.allSatisfy { scalar in
            switch scalar.properties.generalCategory {
            case .uppercaseLetter, .lowercaseLetter, .titlecaseLetter, .modifierLetter,
                 .otherLetter, .nonspacingMark, .spacingMark, .decimalNumber:
                return true
            default:
                return "-/'’+#".unicodeScalars.contains(scalar)
            }
        }
    }
}

private extension String {
    func trimmingWhitespace() -> String {
        String(drop(while: \.isWhitespace).reversed().drop(while: \.isWhitespace).reversed())
    }
}
