import VitekEngine

/// Pure-Swift, zero-Foundation Vietnamese gesture / swipe path decoder (`GlideDecoder`).
/// Matches a sequence of visited QWERTY letter keys (`sampledKeys`) against an O(1) endpoint-indexed
/// Vietnamese lexicon + personal frequency memory + sentence context ranker.
public enum GlideDecoder {
    private struct IndexedWord: Sendable {
        let surface: String
        let folded: [UInt8]
        let basePriority: Int
    }

    private struct BucketKey: Hashable, Sendable {
        let first: UInt8
        let last: UInt8
    }

    private static let indexByEndpoints: [BucketKey: [IndexedWord]] = {
        var bestByLower: [String: (surface: String, priority: Int)] = [:]

        func ingest(_ rawWord: String, priority: Int) {
            let trimmed = rawWord.lowercased()
            guard trimmed.count >= 2, trimmed.count <= 10, trimmed.allSatisfy(\.isLetter) else { return }
            let surface = rawWord == rawWord.uppercased() && rawWord.count > 1 ? trimmed : trimmed
            if let existing = bestByLower[trimmed] {
                if priority > existing.priority {
                    bestByLower[trimmed] = (surface, priority)
                }
            } else {
                bestByLower[trimmed] = (surface, priority)
            }
        }

        for entry in BuiltinVocabulary.entries {
            if entry.text.contains(" ") {
                for token in entry.text.split(separator: " ") {
                    ingest(String(token), priority: max(180, entry.priority))
                }
            } else {
                ingest(entry.text, priority: entry.priority)
            }
        }

        // Core high-frequency everyday Vietnamese syllables guaranteed in the glide lexicon
        let coreEveryday = """
        xin chào cảm ơn bạn anh chị em mình tôi chúng ta mọi người hôm nay ngày mai
        được không chưa rồi đang sẽ rất quá nhé nha ạ ơi đi làm về ăn uống ngủ nghỉ
        việt nam tiếng chuyện trường đường thành phố nhà phòng công ty dự án báo cáo
        kiểm tra gửi nhận xem giúp hỗ trợ thời gian điện thoại máy tính bàn phím
        """
        for token in coreEveryday.split(whereSeparator: \.isWhitespace) {
            ingest(String(token), priority: 420)
        }

        var buckets: [BucketKey: [IndexedWord]] = [:]
        for (_, item) in bestByLower {
            let keyStr = Spelling.lookupKey(item.surface)
            let bytes = Array(keyStr.utf8)
            guard bytes.count >= 2,
                  let first = bytes.first, let last = bytes.last,
                  (97...122).contains(first), (97...122).contains(last) else { continue }
            let bucket = BucketKey(first: first, last: last)
            buckets[bucket, default: []].append(IndexedWord(
                surface: item.surface,
                folded: bytes,
                basePriority: item.priority
            ))
        }
        return buckets
    }()

    /// Decodes a continuous finger swipe sequence across QWERTY letter keys into ranked Vietnamese words.
    /// `sampledKeys` contains the ordered sequence of keys the finger passed through (first = touch-down, last = lift).
    public static func decode(
        sampledKeys: [Character],
        previousWords: [String] = [],
        domain: VocabularyDomain? = nil,
        personal: PersonalFrequency? = nil,
        capitalizeFirst: Bool = false,
        limit: Int = 3
    ) -> [WordCandidate] {
        guard limit > 0, sampledKeys.count >= 2 else { return [] }

        // Deduplicate consecutive identical keys while preserving ordered path
        var path: [UInt8] = []
        path.reserveCapacity(sampledKeys.count)
        for ch in sampledKeys {
            let folded = Spelling.lookupKey(String(ch))
            guard let b = folded.utf8.first, (97...122).contains(b) else { continue }
            if path.last != b {
                path.append(b)
            }
        }
        guard path.count >= 2, let first = path.first, let last = path.last else { return [] }

        let bucket = BucketKey(first: first, last: last)
        var pool = indexByEndpoints[bucket] ?? []

        if let personal, !personal.unigrams.isEmpty {
            for (word, count) in personal.unigrams where count >= 2 {
                let folded = Array(Spelling.lookupKey(word).utf8)
                guard folded.count >= 2, folded.first == first, folded.last == last else { continue }
                pool.append(IndexedWord(surface: word, folded: folded, basePriority: 360 + min(count * 35, 300)))
            }
        }
        guard !pool.isEmpty else { return [] }

        // Contextual next-word followers for huge disambiguation boost (e.g. `cảm` -> `ơn`, `việt` -> `nam`)
        var contextBoostByWord: [String: Int] = [:]
        if !previousWords.isEmpty {
            let followers = PredictionLexicon.standard.matches(before: previousWords, prefix: "", domain: domain)
            for match in followers {
                contextBoostByWord[match.text.lowercased()] = max(contextBoostByWord[match.text.lowercased()] ?? 0, match.score)
            }
            if let personal {
                for cand in personal.matches(before: previousWords, prefix: "", limit: 8) {
                    contextBoostByWord[cand.text.lowercased()] = max(contextBoostByWord[cand.text.lowercased()] ?? 0, cand.score)
                }
            }
        }

        struct Scored {
            let text: String
            let score: Int
        }

        var scored: [Scored] = []
        scored.reserveCapacity(16)

        for item in pool {
            guard let pathScore = scoreAlignment(wordBytes: item.folded, pathBytes: path) else { continue }
            let contextBonus = (contextBoostByWord[item.surface] ?? 0) / 2
            // Slight bonus for accented Vietnamese words when unaccented keys were swiped
            let hasDiacritic = item.surface.utf8.count > item.folded.count
            let accentBonus = hasDiacritic ? 45 : 0
            let total = pathScore + item.basePriority + contextBonus + accentBonus
            scored.append(Scored(text: item.surface, score: total))
        }

        scored.sort {
            if $0.score != $1.score { return $0.score > $1.score }
            return $0.text < $1.text
        }

        var seen = Set<String>()
        var results: [WordCandidate] = []
        for entry in scored where seen.insert(entry.text).inserted {
            let formatted = capitalizeFirst ? capitalizeLeading(entry.text) : entry.text
            results.append(WordCandidate(
                text: formatted,
                source: .dictionary,
                score: entry.score,
                appendsSpace: true
            ))
            if results.count == limit { break }
        }
        return results
    }

    /// Evaluates how well `wordBytes` aligns as an ordered subsequence along `pathBytes`.
    /// First and last bytes are already guaranteed equal. Allows at most 1 skipped interior letter
    /// for 5+ letter words when swiping fast across adjacent keys.
    private static func scoreAlignment(wordBytes: [UInt8], pathBytes: [UInt8]) -> Int? {
        let wCount = wordBytes.count
        let pCount = pathBytes.count
        // Deduplicate double letters in target word (`oo` -> `o`) since a swipe rests once on a key
        var target: [UInt8] = []
        target.reserveCapacity(wCount)
        for b in wordBytes where target.last != b {
            target.append(b)
        }

        guard target.count >= 2 else { return nil }
        if pCount + 1 < target.count { return nil }

        // Greedy ordered subsequence match on interior letters `target[1 ..< target.count - 1]`
        var pIdx = 1
        let pEnd = pCount - 1
        var matchedInterior = 0
        let interiorCount = target.count - 2

        if interiorCount > 0 {
            for tIdx in 1..<(target.count - 1) {
                let needed = target[tIdx]
                var foundAt: Int?
                var scan = pIdx
                while scan < pEnd {
                    if pathBytes[scan] == needed {
                        foundAt = scan
                        break
                    }
                    scan += 1
                }
                if let pos = foundAt {
                    matchedInterior += 1
                    pIdx = pos + 1
                }
            }
        }

        let missed = interiorCount - matchedInterior
        let allowedMisses = target.count >= 5 ? 1 : 0
        guard missed <= allowedMisses else { return nil }

        let extraPathKeys = max(0, pCount - target.count)
        // Too many unrelated detours means the user swiped a much longer shape
        guard extraPathKeys <= 8 else { return nil }

        var score = 1_000
        score += matchedInterior * 140
        score -= missed * 260
        score -= extraPathKeys * 35
        return score
    }

    private static func capitalizeLeading(_ word: String) -> String {
        guard let first = word.first else { return word }
        return String(first).uppercased() + word.dropFirst()
    }
}
