import VitekEngine

/// Bounded, on-device personal frequency memory for words and 2-word phrases.
/// Pure Swift standard library: zero Foundation, O(1) indexed lookup by previous word and
/// first folded ASCII letter, strictly capped in size for iOS keyboard extension memory limits.
public struct PersonalFrequency: Sendable, Equatable {
    public static let maxEntries = 500

    public private(set) var unigrams: [String: Int]
    public private(set) var bigrams: [String: Int]

    private var bigramsByPrevious: [String: [String: Int]] = [:]
    private var unigramsByBucket: [UInt8: [String]] = [:]

    public init(unigrams: [String: Int] = [:], bigrams: [String: Int] = [:]) {
        self.unigrams = unigrams
        self.bigrams = bigrams
        prune()
        rebuildIndexes()
    }

    public static func == (lhs: PersonalFrequency, rhs: PersonalFrequency) -> Bool {
        lhs.unigrams == rhs.unigrams && lhs.bigrams == rhs.bigrams
    }

    public var isEmpty: Bool { unigrams.isEmpty && bigrams.isEmpty }
    public var totalCount: Int { unigrams.count + bigrams.count }

    /// Records a committed word and (optionally) the immediately preceding word.
    public mutating func record(word: String, after previous: String? = nil) {
        guard Self.isTrackable(word) else { return }
        let lower = word.lowercased()
        let isNewUnigram = unigrams[lower] == nil
        unigrams[lower, default: 0] += 1
        if isNewUnigram, let bucket = Self.bucketKey(for: lower) {
            unigramsByBucket[bucket, default: []].append(lower)
        }
        if let previous, Self.isTrackable(previous) {
            let prevLower = previous.lowercased()
            let pair = prevLower + " " + lower
            let updated = (bigrams[pair] ?? 0) + 1
            bigrams[pair] = updated
            bigramsByPrevious[prevLower, default: [:]][lower] = updated
        }
        if unigrams.count > Self.maxEntries || bigrams.count > Self.maxEntries {
            prune()
            rebuildIndexes()
        }
    }

    public mutating func reset() {
        unigrams.removeAll()
        bigrams.removeAll()
        bigramsByPrevious.removeAll()
        unigramsByBucket.removeAll()
    }

    /// Returns personal candidates matching `before` and `prefix` using O(1) bucketed lookup.
    public func matches(before: [String], prefix: String, limit: Int = 5) -> [WordCandidate] {
        guard limit > 0, !isEmpty else { return [] }
        var results: [WordCandidate] = []

        if let previous = before.last, let followers = bigramsByPrevious[previous.lowercased()] {
            for (next, count) in followers {
                guard prefix.isEmpty || Spelling.word(next, continues: prefix) else { continue }
                guard let formatted = Suggestions.prepare([next], prefix: prefix, limit: 1).first else { continue }
                let score = 900 + min(count * 40, 400)
                results.append(WordCandidate(text: formatted, source: .phrase, score: score, appendsSpace: true))
            }
        }

        if !prefix.isEmpty, let bucket = Self.bucketKey(for: prefix), let words = unigramsByBucket[bucket] {
            for word in words where Spelling.word(word, continues: prefix) {
                guard let count = unigrams[word],
                      let formatted = Suggestions.prepare([word], prefix: prefix, limit: 1).first else { continue }
                let score = 400 + min(count * 30, 300)
                results.append(WordCandidate(text: formatted, source: .dictionary, score: score, appendsSpace: true))
            }
        }

        results.sort {
            if $0.score != $1.score { return $0.score > $1.score }
            return $0.text < $1.text
        }
        return Array(results.prefix(limit))
    }

    private mutating func prune() {
        if unigrams.count > Self.maxEntries {
            let kept = unigrams.sorted { $0.value > $1.value }.prefix(Self.maxEntries)
            unigrams = Dictionary(uniqueKeysWithValues: kept.map { ($0.key, $0.value) })
        }
        if bigrams.count > Self.maxEntries {
            let kept = bigrams.sorted { $0.value > $1.value }.prefix(Self.maxEntries)
            bigrams = Dictionary(uniqueKeysWithValues: kept.map { ($0.key, $0.value) })
        }
    }

    private mutating func rebuildIndexes() {
        unigramsByBucket.removeAll(keepingCapacity: true)
        for word in unigrams.keys {
            if let bucket = Self.bucketKey(for: word) {
                unigramsByBucket[bucket, default: []].append(word)
            }
        }
        bigramsByPrevious.removeAll(keepingCapacity: true)
        for (pair, count) in bigrams {
            guard let space = pair.firstIndex(of: " ") else { continue }
            let prev = String(pair[..<space])
            let next = String(pair[pair.index(after: space)...])
            bigramsByPrevious[prev, default: [:]][next] = count
        }
    }

    private static func bucketKey(for text: String) -> UInt8? {
        guard let first = text.first else { return nil }
        let folded = Spelling.lookupKey(String(first))
        return folded.utf8.first
    }

    private static func isTrackable(_ word: String) -> Bool {
        let count = word.count
        guard count >= 2, count <= 32 else { return false }
        return word.allSatisfy(\.isLetter)
    }
}
