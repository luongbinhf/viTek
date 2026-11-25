import VitekEngine

public enum VocabularyDomain: String, Sendable, CaseIterable {
    case general, technology, business, education, health, science
}

/// Project-authored or caller-supplied vocabulary. Priority is editorial, not corpus frequency.
public struct VocabularyEntry: Sendable {
    public let text: String
    public let domain: VocabularyDomain
    public let priority: Int

    public init(_ text: String, domain: VocabularyDomain = .general, priority: Int = 100) {
        self.text = text
        self.domain = domain
        self.priority = min(1_000, max(0, priority))
    }
}

/// Immutable indices, built once and shared across fields. No user typing is retained.
/// A word bucket uses at most three folded letters; a context edge uses its last word.
public struct PredictionLexicon: Sendable {
    public static let standard = PredictionLexicon(entries: BuiltinVocabulary.entries)
    public let entryCount: Int
    public let rejectedEntryCount: Int
    public let wordCount: Int
    private let prefixes: [String: [Word]]
    private let continuations: [String: [Edge]]

    private struct Word: Sendable {
        let text: String
        let domain: VocabularyDomain
        let priority: Int
    }
    private struct Edge: Sendable {
        let before: [String]
        let next: Word
    }
    struct Match {
        let text: String
        let score: Int
        let source: WordCandidate.Source
    }

    public init(entries: [VocabularyEntry]) {
        var prefixes: [String: [Word]] = [:]
        var edges: [String: [Edge]] = [:]
        var unique: [String: Word] = [:]
        var accepted = 0
        for entry in entries {
            // No control characters, multiline entries, hidden marks or unbounded phrases.
            let parts = entry.text.split(separator: " ", omittingEmptySubsequences: false).map(String.init)
            guard entry.text.utf8.count <= 1_024, (1...8).contains(parts.count),
                  parts.allSatisfy(Suggestions.isToken) else { continue }
            accepted += 1
            for (index, part) in parts.enumerated() {
                let word = Word(text: part, domain: entry.domain, priority: entry.priority)
                let identity = entry.domain.rawValue + ":" + part.lowercased()
                if unique[identity].map({ $0.priority < word.priority }) ?? true { unique[identity] = word }
                if index > 0 {
                    let edge = Edge(before: Array(parts[..<index].suffix(5)), next: word)
                    edges[Spelling.lookupKey(parts[index - 1]), default: []].append(edge)
                }
            }
        }
        // Dictionary iteration order must not affect ties or the visible bar.
        for word in unique.values.sorted(by: { $0.text < $1.text }) {
            let key = Spelling.lookupKey(word.text)
            for length in 1...min(3, key.count) {
                prefixes[String(key.prefix(length)), default: []].append(word)
            }
        }
        self.prefixes = prefixes
        continuations = edges
        entryCount = accepted
        rejectedEntryCount = entries.count - accepted
        wordCount = Set(unique.values.map { $0.text.lowercased() }).count
    }

    func matches(before: [String], prefix: String, domain: VocabularyDomain?) -> [Match] {
        var matches: [Match] = []
        var inferredDomains = Set<VocabularyDomain>()
        var bestLength = 0
        if let last = before.last {
            for edge in continuations[Spelling.lookupKey(last)] ?? [] {
                guard before.count >= edge.before.count,
                      zip(before.suffix(edge.before.count), edge.before).allSatisfy({ typed, expected in
                          typed.count == expected.count && Spelling.word(expected, continues: typed)
                      }), Spelling.word(edge.next.text, continues: prefix) else { continue }
                if prefix.isEmpty, edge.before.count == 1 {
                    // A complete preceding word has stronger evidence than an unaccented
                    // prefix. In running prose a lone specialist syllable is ambiguous.
                    guard last == edge.before[0].lowercased(),
                          before.count == 1 || edge.next.domain == .general || edge.next.domain == domain
                    else { continue }
                }
                guard edge.before.count >= bestLength else { continue }
                if edge.before.count > bestLength {
                    matches.removeAll(keepingCapacity: true)
                    inferredDomains.removeAll(keepingCapacity: true)
                    bestLength = edge.before.count
                }
                inferredDomains.insert(edge.next.domain)
                matches.append(Match(text: edge.next.text,
                                     score: edge.before.count * 10_000 + edge.next.priority,
                                     source: .phrase))
            }
        }
        // One letter without a phrase anchor is too ambiguous; no random next-word fallback.
        if prefix.count >= 2 {
            let bucket = String(Spelling.lookupKey(prefix).prefix(3))
            for word in prefixes[bucket] ?? [] where Spelling.word(word.text, continues: prefix) {
                let domainBoost = domain == word.domain || inferredDomains.contains(word.domain) ? 500 : 0
                matches.append(Match(text: word.text, score: word.priority + domainBoost, source: .dictionary))
            }
        }
        return matches
    }
}
