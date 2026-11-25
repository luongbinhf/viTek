import VitekEngine

public struct WordCandidate: Sendable, Equatable {
    public enum Source: String, Sendable { case dictionary, phrase, identifier, keyword, system, emoji }
    public let text: String
    public let source: Source
    public let score: Int
    public let appendsSpace: Bool
    public var insertion: String { text + (appendsSpace ? " " : "") }
}

/// Local, deterministic completion. The host retains ownership of focus/caret validation.
public enum WordPrediction {
    public enum Mode: Sendable { case automatic, prose, code }
    public enum Policy: Sendable { case prose, code, suppressed }
    public static let contextLimit = 512

    public static func policy(context: String, prefix: String, mode: Mode = .automatic) -> Policy {
        guard prefix.count <= 80, Terminology.prefixLength(context: context, prefix: prefix) != nil else { return .suppressed }
        let bounded = String(context.suffix(contextLimit))
        let before = String(bounded.dropLast(prefix.count))
        // Do not offer a replacement for the tail of a different token or identifier.
        if let last = before.last, last.isLetter || last.isNumber || last == "_" || last == "$" { return .suppressed }
        let token = bounded.split(whereSeparator: \.isWhitespace).last.map(String.init) ?? ""
        if token.contains("://") || token.contains("@") || token.hasPrefix("/") && !token.hasPrefix("//") ||
            token.hasPrefix("./") || token.hasPrefix("../") || token.hasPrefix("~/") || token.contains("\\") {
            return .suppressed
        }
        let code = CodeCompletion.inspect(before)
        if mode == .code { return code.insideText ? .suppressed : .code }
        if mode == .automatic, code.hasCode, !code.insideText { return .code }
        // Member access is not a Vietnamese word boundary, even for an unknown receiver.
        guard before.isEmpty || before.last?.isWhitespace == true || "([{\"'“‘".contains(before.last!) else { return .suppressed }
        return .prose
    }

    public static func suggest(context: String, prefix: String, mode: Mode = .automatic,
                               domain: VocabularyDomain? = nil, lexicon: PredictionLexicon = .standard,
                               personal: PersonalFrequency? = nil,
                               systemCandidates: [String] = [],
                               shortcuts: Shortcuts? = nil,
                               rawPrefix: String? = nil,
                               limit: Int = 5) -> [WordCandidate] {
        guard limit > 0 else { return [] }
        let bounded = context.suffix(contextLimit)
        let before = String(bounded.dropLast(prefix.count))
        let candidates: [WordCandidate]
        switch policy(context: context, prefix: prefix, mode: mode) {
        case .suppressed: return []
        case .code: candidates = CodeCompletion.candidates(before: before, prefix: prefix)
        case .prose:
            let previous = proseWords(before[...])
            let personalMatches = personal?.matches(before: previous, prefix: prefix, limit: limit) ?? []
            let local = lexicon.matches(before: previous, prefix: prefix, domain: domain).compactMap { match -> WordCandidate? in
                guard let text = Suggestions.prepare([match.text], prefix: prefix, limit: 1).first else { return nil }
                return WordCandidate(text: text, source: match.source, score: match.score, appendsSpace: true)
            }
            let emoji: [WordCandidate]
            if let matched = EmojiSuggestions.match(before: previous, prefix: prefix) {
                emoji = [WordCandidate(text: matched, source: .emoji, score: -100, appendsSpace: true)]
            } else {
                emoji = []
            }
            let shortcutMatches: [WordCandidate] = prefix.isEmpty ? [] :
                (shortcuts?.candidateExpansions(forPrefix: prefix, rawPrefix: rawPrefix, limit: 2) ?? []).enumerated().map {
                    WordCandidate(text: $0.element, source: .phrase, score: 2_200 - $0.offset, appendsSpace: true)
                }
            // Once a phrase or shortcut completes the typed prefix, unrelated dictionary entries
            // and system spellings should not fill the remaining slots in the bar.
            let phrases = shortcutMatches + (personalMatches + local).filter { $0.source == .phrase }
            if !phrases.isEmpty {
                candidates = phrases + (prefix.isEmpty ? emoji : [])
            } else {
                let system = (prefix.count < 2 ? [] : Suggestions.prepare(systemCandidates, prefix: prefix, limit: 32)).enumerated().map {
                    WordCandidate(text: $0.element, source: .system, score: -$0.offset - 1, appendsSpace: true)
                }
                candidates = personalMatches + local + system + emoji
            }
        }
        var seen = Set<String>()
        return Array(candidates.sorted {
            if $0.score != $1.score { return $0.score > $1.score }
            return $0.text < $1.text
        }.filter {
            // Prose is case-insensitive; identifiers differing only in case are distinct.
            seen.insert($0.appendsSpace ? $0.text.lowercased() : $0.text).inserted
        }.prefix(min(limit, 32)))
    }

    public static func words(context: String, prefix: String, limit: Int = 5) -> [String] {
        suggest(context: context, prefix: prefix, limit: limit).map(\.text)
    }

    /// Only contiguous words in the current sentence. Punctuation is a hard phrase boundary.
    static func proseWords(_ before: Substring) -> [String] {
        var start = before.endIndex
        while start > before.startIndex {
            let prev = before.index(before: start)
            let ch = before[prev]
            guard !ch.isNewline && (ch.isLetter || ch.isWhitespace) else { break }
            start = prev
        }
        let slice = before[start...]
        guard !slice.isEmpty else { return [] }
        return slice.split(whereSeparator: \.isWhitespace).suffix(5).map { $0.lowercased() }
    }
}
