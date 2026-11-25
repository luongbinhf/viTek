import VitekEngine

/// A collision-free shortcut candidate mined from repeated personal bigrams and trigrams.
public struct SuggestedShortcut: Sendable, Equatable {
    public let abbreviation: String
    public let phrase: String
    public let count: Int

    public init(abbreviation: String, phrase: String, count: Int) {
        self.abbreviation = abbreviation
        self.phrase = phrase
        self.count = count
    }
}

/// Bounded, on-device personal frequency memory for 1-word unigrams, 2-word bigrams, and 3-word trigrams.
/// Pure Swift standard library: zero Foundation, O(1) indexed lookup by previous context and
/// first folded ASCII letter, strictly capped in size for iOS keyboard extension memory limits.
public struct PersonalFrequency: Sendable, Equatable {
    public static let maxEntries = 500

    public private(set) var unigrams: [String: Int]
    public private(set) var bigrams: [String: Int]
    public private(set) var trigrams: [String: Int]

    private var bigramsByPrevious: [String: [String: Int]] = [:]
    private var trigramsByPair: [String: [String: Int]] = [:]
    private var unigramsByBucket: [UInt8: [String]] = [:]

    public init(unigrams: [String: Int] = [:], bigrams: [String: Int] = [:], trigrams: [String: Int] = [:]) {
        self.unigrams = unigrams
        self.bigrams = bigrams
        self.trigrams = trigrams
        prune()
        rebuildIndexes()
    }

    public static func == (lhs: PersonalFrequency, rhs: PersonalFrequency) -> Bool {
        lhs.unigrams == rhs.unigrams && lhs.bigrams == rhs.bigrams && lhs.trigrams == rhs.trigrams
    }

    public var isEmpty: Bool { unigrams.isEmpty && bigrams.isEmpty && trigrams.isEmpty }
    public var totalCount: Int { unigrams.count + bigrams.count + trigrams.count }

    /// Records a committed word and up to two preceding words (`beforeThat previous word`).
    public mutating func record(word: String, after previous: String? = nil, beforeThat: String? = nil) {
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

            if let beforeThat, Self.isTrackable(beforeThat) {
                let contextPair = beforeThat.lowercased() + " " + prevLower
                let trigramKey = contextPair + " " + lower
                let updatedTrigram = (trigrams[trigramKey] ?? 0) + 1
                trigrams[trigramKey] = updatedTrigram
                trigramsByPair[contextPair, default: [:]][lower] = updatedTrigram
            }
        }
        if unigrams.count > Self.maxEntries || bigrams.count > Self.maxEntries || trigrams.count > Self.maxEntries {
            prune()
            rebuildIndexes()
        }
    }

    public mutating func reset() {
        unigrams.removeAll()
        bigrams.removeAll()
        trigrams.removeAll()
        bigramsByPrevious.removeAll()
        trigramsByPair.removeAll()
        unigramsByBucket.removeAll()
    }

    /// Combines counts from another synced `PersonalFrequency` using `max(local, remote)` per entry.
    public mutating func merge(_ other: PersonalFrequency) {
        for (word, count) in other.unigrams {
            unigrams[word] = max(unigrams[word] ?? 0, count)
        }
        for (pair, count) in other.bigrams {
            bigrams[pair] = max(bigrams[pair] ?? 0, count)
        }
        for (triple, count) in other.trigrams {
            trigrams[triple] = max(trigrams[triple] ?? 0, count)
        }
        prune()
        rebuildIndexes()
    }

    /// Exports bounded top entries suitable for `NSUbiquitousKeyValueStore` sync.
    public func cloudSnapshot(limit: Int = 180) -> (unigrams: [String: Int], bigrams: [String: Int], trigrams: [String: Int]) {
        func top(_ dict: [String: Int]) -> [String: Int] {
            guard limit > 0 else { return [:] }
            let sorted = dict.sorted {
                if $0.value != $1.value { return $0.value > $1.value }
                return $0.key < $1.key
            }
            return Dictionary(uniqueKeysWithValues: sorted.prefix(limit).map { ($0.key, $0.value) })
        }
        return (top(unigrams), top(bigrams), top(trigrams))
    }

    /// Returns personal candidates matching 3-word (`before[n-2, n-1]`), 2-word (`before.last`), and 1-word prefix.
    public func matches(before: [String], prefix: String, limit: Int = 5) -> [WordCandidate] {
        guard limit > 0, !isEmpty else { return [] }
        var results: [WordCandidate] = []

        if before.count >= 2 {
            let contextPair = before[before.count - 2].lowercased() + " " + before[before.count - 1].lowercased()
            if let followers = trigramsByPair[contextPair] {
                for (next, count) in followers {
                    guard prefix.isEmpty || Spelling.word(next, continues: prefix) else { continue }
                    guard let formatted = Suggestions.prepare([next], prefix: prefix, limit: 1).first else { continue }
                    let score = 1_400 + min(count * 50, 400)
                    results.append(WordCandidate(text: formatted, source: .phrase, score: score, appendsSpace: true))
                }
            }
        }

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
        var seen = Set<String>()
        var unique: [WordCandidate] = []
        for candidate in results where seen.insert(candidate.text.lowercased()).inserted {
            unique.append(candidate)
            if unique.count == limit { break }
        }
        return unique
    }

    /// Mines repeated 2-word and 3-word phrases from personal typing history into collision-free
    /// initialism shortcuts (e.g. `"cảm ơn bạn"` → `"cob"`, `"tài khoản"` → `"tk"`), excluding any
    /// abbreviation that already exists or forms a valid Vietnamese syllable or common English word.
    public func suggestedShortcuts(
        excluding existingAbbreviations: Set<String> = [],
        existingExpansions: Set<String> = [],
        minCount: Int = 4,
        limit: Int = 5
    ) -> [SuggestedShortcut] {
        guard limit > 0, minCount > 0, (!bigrams.isEmpty || !trigrams.isEmpty) else { return [] }
        let blockedAbbr = Set(existingAbbreviations.map { $0.lowercased() })
        let blockedPhrases = Set(existingExpansions.map { $0.lowercased() })

        struct RankedCandidate {
            let suggestion: SuggestedShortcut
            let score: Int
        }

        var candidates: [RankedCandidate] = []

        func consider(phrase: String, count: Int, wordBonus: Int) {
            guard count >= minCount, phrase.count >= 6 else { return }
            let lowerPhrase = phrase.lowercased()
            guard !blockedPhrases.contains(lowerPhrase) else { return }
            let parts = lowerPhrase.split(separator: " ")
            guard (2...4).contains(parts.count) else { return }
            var abbr = ""
            abbr.reserveCapacity(parts.count)
            for part in parts {
                guard let first = part.first else { return }
                let folded = Spelling.lookupKey(String(first))
                guard let ascii = folded.first, ascii >= "a", ascii <= "z" else { return }
                abbr.append(ascii)
            }
            guard abbr.count >= 2,
                  !blockedAbbr.contains(abbr),
                  !Spelling.isCollisionProneAbbreviation(abbr),
                  !EnglishWords.contains(abbr) else { return }
            candidates.append(RankedCandidate(
                suggestion: SuggestedShortcut(abbreviation: abbr, phrase: lowerPhrase, count: count),
                score: count * wordBonus + min(lowerPhrase.count, 20)
            ))
        }

        for (triple, count) in trigrams {
            consider(phrase: triple, count: count, wordBonus: 15)
        }
        for (pair, count) in bigrams {
            consider(phrase: pair, count: count, wordBonus: 10)
        }

        candidates.sort {
            if $0.score != $1.score { return $0.score > $1.score }
            if $0.suggestion.count != $1.suggestion.count { return $0.suggestion.count > $1.suggestion.count }
            return $0.suggestion.phrase < $1.suggestion.phrase
        }

        var usedAbbr = Set<String>()
        var usedPhrases = Set<String>()
        var results: [SuggestedShortcut] = []
        for entry in candidates {
            guard usedAbbr.insert(entry.suggestion.abbreviation).inserted,
                  usedPhrases.insert(entry.suggestion.phrase).inserted else { continue }
            results.append(entry.suggestion)
            if results.count == limit { break }
        }
        return results
    }

    private mutating func prune() {
        func clamp(_ dict: [String: Int]) -> [String: Int] {
            guard dict.count > Self.maxEntries else { return dict }
            let kept = dict.sorted {
                if $0.value != $1.value { return $0.value > $1.value }
                return $0.key < $1.key
            }.prefix(Self.maxEntries)
            return Dictionary(uniqueKeysWithValues: kept.map { ($0.key, $0.value) })
        }
        unigrams = clamp(unigrams)
        bigrams = clamp(bigrams)
        trigrams = clamp(trigrams)
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
        trigramsByPair.removeAll(keepingCapacity: true)
        for (triple, count) in trigrams {
            let parts = triple.split(separator: " ", omittingEmptySubsequences: false)
            guard parts.count == 3 else { continue }
            let contextPair = String(parts[0]) + " " + String(parts[1])
            let next = String(parts[2])
            trigramsByPair[contextPair, default: [:]][next] = count
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
