/// One row of the user's shortcut list, in the order the user keeps it.
public struct ShortcutEntry: Sendable, Equatable {
    public var abbreviation: String
    public var expansion: String

    public init(abbreviation: String, expansion: String) {
        self.abbreviation = abbreviation
        self.expansion = expansion
    }
}

/// The text format for importing and exporting shortcuts. UTF-8, one shortcut per line.
///
/// Supported import formats:
/// - viTek native: `ko<TAB>không` or `vn   Việt Nam` (`\n`, `\r`, `\t`, `\\` unescaped)
/// - UniKey / OpenKey: `ko:không` (skips `#DO NOT DELETE THIS LINE***` and `;` comments)
/// - CSV (RFC 4180): `ko,không` or `"dc","Hà Nội, Việt Nam"` (skips `abbreviation,expansion` header)
public enum ShortcutFile {
    public struct Parsed: Sendable, Equatable {
        public var entries: [ShortcutEntry]
        /// 1-based numbers of the lines that hold no abbreviation and expansion pair.
        public var rejectedLines: [Int]
    }

    public static func parse(_ text: String) -> Parsed {
        var parsed = Parsed(entries: [], rejectedLines: [])
        // "\r\n" is one Character in Swift, so Windows line ends need their own case.
        let lines = text.split(omittingEmptySubsequences: false) { $0 == "\n" || $0 == "\r\n" || $0 == "\r" }
        for (index, line) in lines.enumerated() {
            let trimmed = line.drop(while: { $0 == " " || $0 == "\t" })
            if trimmed.isEmpty || trimmed.first == "#" || trimmed.first == ";" { continue }
            if index == 0, isCSVHeader(trimmed) { continue }
            guard let entry = entry(in: line) else {
                parsed.rejectedLines.append(index + 1)
                continue
            }
            parsed.entries.append(entry)
        }
        return parsed
    }

    public static func format(_ entries: [ShortcutEntry]) -> String {
        var text = "# viTek: chữ tắt<TAB>cụm thay thế\n"
        for entry in entries where !entry.abbreviation.isEmpty && !entry.expansion.isEmpty {
            text += entry.abbreviation + "\t" + escaped(entry.expansion) + "\n"
        }
        return text
    }

    public static func formatCSV(_ entries: [ShortcutEntry]) -> String {
        var text = "abbreviation,expansion\n"
        for entry in entries where !entry.abbreviation.isEmpty && !entry.expansion.isEmpty {
            text += csvField(entry.abbreviation) + "," + csvField(entry.expansion) + "\n"
        }
        return text
    }

    private static func isCSVHeader(_ line: Substring) -> Bool {
        guard let fields = parseCSVRow(line), fields.count == 2 else { return false }
        let first = fields[0].lowercased()
        let second = fields[1].lowercased()
        return (first == "abbreviation" || first == "shortcut" || first == "key" || first == "chữ tắt")
            && (second == "expansion" || second == "replacement" || second == "value" || second == "thay bằng")
    }

    private static func entry(in line: Substring) -> ShortcutEntry? {
        if let tab = line.firstIndex(of: "\t") {
            let abbreviation = String(line[..<tab]).trimmingSpaces()
            let expansion = unescaped(line[line.index(after: tab)...])
            return validated(abbreviation: abbreviation, expansion: expansion)
        }
        if line.first == "\"", let fields = parseCSVRow(line), fields.count == 2 {
            return validated(abbreviation: fields[0].trimmingSpaces(), expansion: fields[1])
        }
        // UniKey / OpenKey macro format: `abbr:expansion` (only when `:` precedes any space or comma).
        if let colon = line.firstIndex(of: ":") {
            let head = line[..<colon]
            if !head.isEmpty, !head.contains(" "), !head.contains(",") {
                let abbreviation = String(head).trimmingSpaces()
                let expansion = unescaped(line[line.index(after: colon)...])
                return validated(abbreviation: abbreviation, expansion: expansion)
            }
        }
        // CSV without leading quote: `abbr,expansion` (only when `,` precedes any space).
        if let comma = line.firstIndex(of: ",") {
            let head = line[..<comma]
            if !head.isEmpty, !head.contains(" "), let fields = parseCSVRow(line), fields.count == 2 {
                return validated(abbreviation: fields[0].trimmingSpaces(), expansion: fields[1])
            }
        }
        if let space = line.firstIndex(of: " ") {
            let abbreviation = String(line[..<space]).trimmingSpaces()
            let rest = line[space...].drop(while: { $0 == " " })
            let expansion = unescaped(rest)
            return validated(abbreviation: abbreviation, expansion: expansion)
        }
        return nil
    }

    private static func validated(abbreviation: String, expansion: String) -> ShortcutEntry? {
        guard !abbreviation.isEmpty, !abbreviation.contains(" "), !expansion.isEmpty else { return nil }
        return ShortcutEntry(abbreviation: abbreviation, expansion: expansion)
    }

    private static func parseCSVRow(_ line: Substring) -> [String]? {
        var fields: [String] = []
        var current = ""
        var index = line.startIndex
        var inQuotes = false
        while index < line.endIndex {
            let ch = line[index]
            if inQuotes {
                if ch == "\"" {
                    let next = line.index(after: index)
                    if next < line.endIndex, line[next] == "\"" {
                        current.append("\"")
                        index = line.index(after: next)
                        continue
                    }
                    inQuotes = false
                } else {
                    current.append(ch)
                }
            } else {
                if ch == "\"" && current.isEmpty {
                    inQuotes = true
                } else if ch == "," {
                    fields.append(current)
                    current = ""
                } else {
                    current.append(ch)
                }
            }
            index = line.index(after: index)
        }
        guard !inQuotes else { return nil }
        fields.append(current)
        return fields
    }

    private static func csvField(_ text: String) -> String {
        if text.contains(",") || text.contains("\"") || text.contains("\n") || text.contains("\r") {
            return "\"" + text.replacingOccurrencesOfQuote() + "\""
        }
        return text
    }

    private static func escaped(_ text: String) -> String {
        var result = ""
        for character in text {
            switch character {
            case "\\": result += "\\\\"
            case "\n": result += "\\n"
            case "\r": result += "\\r"
            case "\r\n": result += "\\r\\n"
            case "\t": result += "\\t"
            default: result.append(character)
            }
        }
        return result
    }

    private static func unescaped(_ text: Substring) -> String {
        var result = ""
        var escaping = false
        for character in text {
            if escaping {
                switch character {
                case "n": result.append("\n")
                case "r": result.append("\r")
                case "t": result.append("\t")
                default: result.append(character)
                }
                escaping = false
            } else if character == "\\" {
                escaping = true
            } else {
                result.append(character)
            }
        }
        if escaping { result.append("\\") }
        return result
    }
}

private extension String {
    func trimmingSpaces() -> String {
        String(drop(while: { $0 == " " || $0 == "\t" }).reversed().drop(while: { $0 == " " || $0 == "\t" }).reversed())
    }

    func replacingOccurrencesOfQuote() -> String {
        var out = ""
        for ch in self {
            if ch == "\"" { out += "\"\"" } else { out.append(ch) }
        }
        return out
    }
}
