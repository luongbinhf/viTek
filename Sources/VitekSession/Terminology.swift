import VitekEngine

/// Compatibility API for phrase-only callers; the host uses WordPrediction's ranked pipeline.
public enum Terminology {
    /// `context` must end with the exact UTF-16 representation of the composing prefix.
    /// Returning nil prevents invalid ranges from reaching a platform completion service.
    public static func prefixLength(context: String, prefix: String) -> Int? {
        guard context.utf16.suffix(prefix.utf16.count).elementsEqual(prefix.utf16) else { return nil }
        return prefix.utf16.count
    }

    public static func candidates(context: String, prefix: String) -> [String] {
        guard prefixLength(context: context, prefix: prefix) != nil else { return [] }
        let preceding = context.dropLast(prefix.count)
        guard preceding.isEmpty || preceding.last?.isWhitespace == true else { return [] }
        var seen = Set<String>()
        var result = PredictionLexicon.standard.matches(
            before: WordPrediction.proseWords(preceding.suffix(WordPrediction.contextLimit)),
            prefix: prefix, domain: nil
        ).filter { $0.source == .phrase }.sorted {
            $0.score == $1.score ? $0.text < $1.text : $0.score > $1.score
        }.map(\.text).filter { seen.insert($0).inserted }
        if prefix.count >= 2 {
            result += BuiltinVocabulary.technicalTokens.filter { $0.lowercased().hasPrefix(prefix.lowercased()) }
        }
        return result
    }
}
