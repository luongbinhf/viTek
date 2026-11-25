/// Local calendar components injected by the host for dynamic shortcut placeholders (`{{date}}`, `{{time}}`).
public struct MacroTimestamp: Sendable, Equatable {
    public var year: Int
    public var month: Int
    public var day: Int
    public var hour: Int
    public var minute: Int

    public init(year: Int, month: Int, day: Int, hour: Int, minute: Int) {
        self.year = year
        self.month = month
        self.day = day
        self.hour = hour
        self.minute = minute
    }

    public var formattedDate: String {
        "\(Self.pad2(day))/\(Self.pad2(month))/\(Self.pad4(year))"
    }

    public var formattedTime: String {
        "\(Self.pad2(hour)):\(Self.pad2(minute))"
    }

    public var formattedDateTime: String {
        "\(formattedTime) \(formattedDate)"
    }

    private static func pad2(_ value: Int) -> String {
        let clamped = max(0, value)
        return clamped < 10 ? "0\(clamped)" : "\(clamped)"
    }

    private static func pad4(_ value: Int) -> String {
        let clamped = max(0, value)
        if clamped < 10 { return "000\(clamped)" }
        if clamped < 100 { return "00\(clamped)" }
        if clamped < 1000 { return "0\(clamped)" }
        return "\(clamped)"
    }
}

/// Text shortcuts expanded when a word ends: `ko` → `không`. Matching ignores case and the
/// expansion follows the case the user typed (`Ko` → `Không`, `KO` → `KHÔNG`), with optional
/// `{{date}}`, `{{time}}`, and `{{datetime}}` placeholders.
public struct Shortcuts: Sendable, Equatable {
    private var table: [String: String]
    private var prefixes: Set<String>
    private var timestampProvider: (@Sendable () -> MacroTimestamp)?

    public init(
        _ entries: [String: String] = [:],
        timestampProvider: (@Sendable () -> MacroTimestamp)? = nil
    ) {
        var normalized: [String: String] = [:]
        var allPrefixes: Set<String> = []
        for (abbreviation, expansion) in entries {
            let lower = abbreviation.lowercased()
            guard !lower.isEmpty else { continue }
            normalized[lower] = expansion
            var current = ""
            for ch in lower {
                current.append(ch)
                allPrefixes.insert(current)
            }
        }
        self.table = normalized
        self.prefixes = allPrefixes
        self.timestampProvider = timestampProvider
    }

    public static func == (lhs: Shortcuts, rhs: Shortcuts) -> Bool {
        lhs.table == rhs.table
    }

    public var isEmpty: Bool { table.isEmpty }

    /// Abbreviations that differ only in case count once.
    public var count: Int { table.count }

    /// True when `prefix` (case-insensitive) is a prefix of at least one registered shortcut abbreviation.
    public func hasPrefix(_ prefix: String) -> Bool {
        guard !prefix.isEmpty, !prefixes.isEmpty else { return false }
        return prefixes.contains(prefix.lowercased())
    }

    public func expansion(of word: String) -> String? {
        guard !word.isEmpty, let rawExpansion = table[word.lowercased()] else { return nil }
        return applyCase(resolveMacros(in: rawExpansion), matching: word)
    }

    /// Returns candidate shortcut expansions whose abbreviation matches `prefix` or `rawPrefix` (at least 2 chars).
    public func candidateExpansions(forPrefix prefix: String, rawPrefix: String? = nil, limit: Int = 2) -> [String] {
        guard limit > 0, !table.isEmpty else { return [] }
        var queries: [String] = []
        if prefix.count >= 2 { queries.append(prefix) }
        if let rawPrefix, rawPrefix.count >= 2, rawPrefix != prefix { queries.append(rawPrefix) }
        guard !queries.isEmpty else { return [] }

        var results: [String] = []
        var seen = Set<String>()
        for query in queries {
            let qLower = query.lowercased()
            guard prefixes.contains(qLower) else { continue }
            let matched = table.filter { $0.key.hasPrefix(qLower) }.sorted { lhs, rhs in
                let lhsExact = lhs.key == qLower
                let rhsExact = rhs.key == qLower
                if lhsExact != rhsExact { return lhsExact && !rhsExact }
                if lhs.key.count != rhs.key.count { return lhs.key.count < rhs.key.count }
                return lhs.key < rhs.key
            }
            for (_, rawExpansion) in matched {
                let formatted = applyCase(resolveMacros(in: rawExpansion), matching: prefix)
                guard formatted.count <= 60,
                      !formatted.contains("\n"), !formatted.contains("\r"),
                      formatted != prefix else { continue }
                if seen.insert(formatted.lowercased()).inserted {
                    results.append(formatted)
                    if results.count == limit { return results }
                }
            }
        }
        return results
    }

    private func applyCase(_ resolved: String, matching word: String) -> String {
        if word == word.lowercased() { return resolved }
        if word.count > 1, word == word.uppercased() { return resolved.uppercased() }
        if let first = word.first, first.isUppercase {
            return resolved.prefix(1).uppercased() + resolved.dropFirst()
        }
        return resolved
    }

    private func resolveMacros(in text: String) -> String {
        guard text.utf8.count >= 8, text.contains("{{") else { return text }
        guard let ts = timestampProvider?() else { return text }
        var result = text.replacing("{{datetime}}", with: ts.formattedDateTime)
        result = result.replacing("{{date}}", with: ts.formattedDate)
        result = result.replacing("{{time}}", with: ts.formattedTime)
        return result
    }
}
