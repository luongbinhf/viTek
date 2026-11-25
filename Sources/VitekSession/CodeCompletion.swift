/// Deliberately lexical: no invented members, inferred types, project scanning or execution.
/// Identifiers come only from this request's bounded context, excluding comments and strings.
enum CodeCompletion {
    struct Context {
        var identifiers: [String] = []
        var insideText = false
        var hasCode = false
    }
    static let keywords = """
    async await actor associatedtype break case catch class const continue default defer def deinit delete
    do elif else enum except export extension false fileprivate final finally for from func function guard
    if import in init interface internal is let mut namespace new nil nonisolated null open override package
    private protocol public raise repeat required return self some static struct super switch throw throws
    true try type typealias typeof var void weak where while yield
    """.split(whereSeparator: \.isWhitespace).map(String.init)
    private static let starters: Set<String> = [
        "let", "var", "const", "func", "function", "class", "struct", "enum", "protocol", "extension",
        "def", "import", "from", "return", "await", "async", "guard", "export", "public", "private",
    ]
    private static let members = [
        "JSON": ["parse", "stringify"],
        "console": ["log", "error", "warn", "info", "debug"],
        "Math": ["abs", "ceil", "floor", "max", "min", "round", "sqrt"],
    ]

    static func identifierCharacter(_ ch: Character) -> Bool {
        guard let byte = ch.asciiValue else { return false }
        return (65...90).contains(byte) || (97...122).contains(byte) || (48...57).contains(byte) || ch == "_" || ch == "$"
    }
    static func isIdentifier(_ word: String) -> Bool {
        guard let first = word.first, !first.isNumber, !word.isEmpty, word.count <= 80 else { return false }
        return word.allSatisfy(identifierCharacter)
    }

    static func inspect(_ before: String) -> Context {
        let chars = Array(before)
        var result = Context()
        var quote: Character?
        var escaped = false
        var lineComment = false
        var blockComment = false
        var token = ""
        var codeLine = ""
        func flush() {
            if isIdentifier(token) { result.identifiers.append(token) }
            token = ""
        }
        var i = 0
        while i < chars.count {
            let ch = chars[i]
            let next: Character? = i + 1 < chars.count ? chars[i + 1] : nil
            if lineComment {
                if ch.isNewline { lineComment = false; codeLine = "" }
            } else if blockComment {
                if ch == "*", next == "/" { blockComment = false; i += 1 }
            } else if let delimiter = quote {
                if escaped { escaped = false }
                else if ch == "\\" { escaped = true }
                else if ch == delimiter { quote = nil }
            } else if ch == "/", next == "/" {
                flush(); lineComment = true; i += 1
            } else if ch == "/", next == "*" {
                flush(); blockComment = true; i += 1
            } else if ch == "#" {
                flush(); lineComment = true
            } else if ch == "\"" || ch == "'" || ch == "`" {
                flush(); quote = ch
            } else {
                if identifierCharacter(ch) { token.append(ch) } else { flush() }
                if ch.isNewline { codeLine = "" } else { codeLine.append(ch) }
            }
            i += 1
        }
        flush()
        result.insideText = lineComment || blockComment || quote != nil
        let first = codeLine.split(whereSeparator: { !$0.isLetter }).first.map(String.init) ?? ""
        result.hasCode = starters.contains(first) || codeLine.contains(" = ") || codeLine.contains("=>") ||
            codeLine.contains("->") || members.keys.contains(where: { codeLine.hasSuffix($0 + ".") })
        return result
    }

    static func candidates(before: String, prefix: String) -> [WordCandidate] {
        guard prefix.count >= 2, isIdentifier(prefix) else { return [] }
        let context = inspect(before)
        guard !context.insideText else { return [] }
        let words: [(String, WordCandidate.Source, Int)]
        if before.last == "." {
            let receiver = String(before.dropLast().reversed().prefix(while: identifierCharacter).reversed())
            words = (members[receiver] ?? []).map { ($0, .keyword, 1_000) }
        } else {
            words = context.identifiers.reversed().enumerated().map { ($0.element, .identifier, 3_000 - $0.offset) } +
                keywords.map { ($0, .keyword, 500) }
        }
        return words.compactMap { text, source, score in
            guard text.hasPrefix(prefix), text != prefix else { return nil }
            return WordCandidate(text: text, source: source, score: score, appendsSpace: false)
        }
    }
}
