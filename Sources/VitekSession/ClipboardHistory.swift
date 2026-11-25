/// Semantic classification of a clipboard snippet for crisp icons, filters, and smart actions.
public enum ClipboardContentKind: String, Sendable, Equatable, CaseIterable {
    case url
    case email
    case phone
    case otp
    case hexColor
    case code
    case multiline
    case text

    public var symbolName: String {
        switch self {
        case .url: "link"
        case .email: "envelope.fill"
        case .phone: "phone.fill"
        case .otp: "key.horizontal.fill"
        case .hexColor: "paintpalette.fill"
        case .code: "chevron.left.forwardslash.chevron.right"
        case .multiline: "doc.text.fill"
        case .text: "text.alignleft"
        }
    }

    public var badgeTitle: String {
        switch self {
        case .url: "Liên kết"
        case .email: "Email"
        case .phone: "Số ĐT"
        case .otp: "Mã số"
        case .hexColor: "Mã màu"
        case .code: "Code"
        case .multiline: "Văn bản"
        case .text: "Ghi chú"
        }
    }

    public var usesMonospacedFont: Bool {
        switch self {
        case .otp, .hexColor, .code: true
        default: false
        }
    }
}

/// Pure-Swift RGB triplet parsed from a CSS/Hex color string (`#RGB`, `#RRGGBB`, `#RRGGBBAA`).
public struct ClipboardRGBColor: Sendable, Equatable {
    public let r: UInt8
    public let g: UInt8
    public let b: UInt8

    public init(r: UInt8, g: UInt8, b: UInt8) {
        self.r = r
        self.g = g
        self.b = b
    }

    public var redFraction: Double { Double(r) / 255.0 }
    public var greenFraction: Double { Double(g) / 255.0 }
    public var blueFraction: Double { Double(b) / 255.0 }
}

/// Filter tabs for the Clipboard palette, settings page, and mobile keyboard picker.
public enum ClipboardFilter: String, Sendable, Equatable, CaseIterable {
    case all
    case pinned
    case linksAndContacts
    case codeAndColor

    public var title: String {
        switch self {
        case .all: "Tất cả"
        case .pinned: "Ghim"
        case .linksAndContacts: "Link & Số"
        case .codeAndColor: "Code & Màu"
        }
    }

    public var symbolName: String {
        switch self {
        case .all: "doc.on.clipboard.fill"
        case .pinned: "pin.fill"
        case .linksAndContacts: "link"
        case .codeAndColor: "chevron.left.forwardslash.chevron.right"
        }
    }

    public func matches(_ item: ClipboardItem) -> Bool {
        switch self {
        case .all:
            return true
        case .pinned:
            return item.isPinned
        case .linksAndContacts:
            switch item.kind {
            case .url, .email, .phone, .otp: return true
            default: return false
            }
        case .codeAndColor:
            switch item.kind {
            case .code, .hexColor: return true
            default: return false
            }
        }
    }
}

/// Pure-Swift clipboard item and history store shared by macOS and iOS without Foundation.
public struct ClipboardItem: Sendable, Equatable {
    public static let maxAliasLength = 60

    public var text: String
    public var alias: String
    public var isPinned: Bool
    public var timestamp: Int

    public init(text: String, alias: String = "", isPinned: Bool = false, timestamp: Int = 0) {
        self.text = text
        self.alias = Self.sanitizeAlias(alias)
        self.isPinned = isPinned
        self.timestamp = timestamp
    }

    /// Collapses contiguous whitespace/newlines and truncates long snippets for compact menus/popups.
    public var preview: String {
        let collapsed = text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        if collapsed.count <= 80 { return collapsed }
        return String(collapsed.prefix(79)) + "…"
    }

    public var kind: ClipboardContentKind {
        Self.classify(text)
    }

    public var parsedHexColor: ClipboardRGBColor? {
        Self.parseHexColor(Self.trimmedText(text))
    }

    public var lineCount: Int {
        guard !text.isEmpty else { return 0 }
        var lines = 1
        for ch in text where ch == "\n" || ch == "\r\n" || ch == "\r" {
            lines += 1
        }
        return lines
    }

    public var characterCount: Int {
        text.count
    }

    public var statsSummary: String {
        let lines = lineCount
        if lines > 1 {
            return "\(lines) dòng · \(characterCount) ký tự"
        }
        return "\(characterCount) ký tự"
    }

    public func relativeTimeText(now: Int) -> String {
        guard timestamp > 0, now >= timestamp else { return "" }
        let delta = now - timestamp
        if delta < 60 { return "Vừa xong" }
        if delta < 3_600 { return "\(delta / 60) phút trước" }
        if delta < 86_400 { return "\(delta / 3_600) giờ trước" }
        return "\(delta / 86_400) ngày trước"
    }

    public var isSmartPasteCandidate: Bool {
        switch kind {
        case .otp, .url, .phone, .email: return true
        default: return false
        }
    }

    public var smartChipTitle: String {
        if !alias.isEmpty {
            return "Dán \(alias)"
        }
        let compact = preview
        switch kind {
        case .otp:
            return "Dán mã \(compact)"
        case .url:
            let stripped: String
            if compact.hasPrefix("https://") {
                stripped = String(compact.dropFirst(8))
            } else if compact.hasPrefix("http://") {
                stripped = String(compact.dropFirst(7))
            } else {
                stripped = compact
            }
            return "Dán \(String(stripped.prefix(20)))"
        case .phone, .email:
            return "Dán \(String(compact.prefix(20)))"
        default:
            return "Dán"
        }
    }

    static func sanitizeAlias(_ raw: String) -> String {
        let collapsed = raw.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        if collapsed.count <= maxAliasLength { return collapsed }
        return String(collapsed.prefix(maxAliasLength))
    }

    private static func trimmedText(_ raw: String) -> String {
        String(raw.drop(while: \.isWhitespace).reversed().drop(while: \.isWhitespace).reversed())
    }

    private static func classify(_ raw: String) -> ClipboardContentKind {
        let trimmed = trimmedText(raw)
        let hasNewline = trimmed.contains { $0 == "\n" || $0 == "\r\n" || $0 == "\r" }
        if !hasNewline {
            let lower = trimmed.lowercased()
            if (lower.hasPrefix("https://") || lower.hasPrefix("http://"))
                && !trimmed.contains(where: \.isWhitespace) {
                return .url
            }
            if parseHexColor(trimmed) != nil {
                return .hexColor
            }
            if looksLikeEmail(trimmed) {
                return .email
            }
            if looksLikeOTP(trimmed) {
                return .otp
            }
            if looksLikePhone(trimmed) {
                return .phone
            }
        }
        if looksLikeCode(trimmed) {
            return .code
        }
        if hasNewline || trimmed.count > 120 {
            return .multiline
        }
        return .text
    }

    private static func looksLikeEmail(_ s: String) -> Bool {
        guard !s.contains(where: \.isWhitespace), s.count <= 120,
              let at = s.firstIndex(of: "@"), at != s.startIndex else { return false }
        let afterAt = s[s.index(after: at)...]
        guard !afterAt.contains("@"), let dot = afterAt.firstIndex(of: "."),
              dot != afterAt.startIndex, afterAt.index(after: dot) < afterAt.endIndex else { return false }
        return true
    }

    private static func looksLikeOTP(_ s: String) -> Bool {
        guard (4...8).contains(s.count) else { return false }
        return s.allSatisfy { $0.isASCII && $0.isNumber }
    }

    private static func looksLikePhone(_ s: String) -> Bool {
        guard !s.isEmpty, s.count <= 22 else { return false }
        var digits = 0
        for ch in s {
            if ch.isASCII && ch.isNumber {
                digits += 1
            } else if ch == "+" || ch == "-" || ch == " " || ch == "." || ch == "(" || ch == ")" {
                continue
            } else {
                return false
            }
        }
        return (9...15).contains(digits)
    }

    private static func looksLikeCode(_ s: String) -> Bool {
        let singleLine = !s.contains { $0 == "\n" || $0 == "\r\n" || $0 == "\r" }
        if singleLine {
            let prefixes = ["git ", "brew ", "swift ", "xcode", "npm ", "pnpm ", "curl ", "ssh ", "sudo ", "chmod ", "export ", "cd ", "./", "xcrun ", "SELECT ", "select "]
            for p in prefixes where s.hasPrefix(p) { return true }
            if (s.hasPrefix("{") && s.hasSuffix("}")) || (s.hasPrefix("[") && s.hasSuffix("]")) {
                return true
            }
            return s.contains(" -> ") || s.contains(" => ") || s.contains(" && ") || s.contains(" == ")
        }
        var syntaxSignals = 0
        let tokens = ["func ", "struct ", "class ", "enum ", "import ", "let ", "var ", "const ", "return ", "if ", "for ", "=>", "{", "}", ";", "</"]
        for token in tokens where s.contains(token) {
            syntaxSignals += 1
            if syntaxSignals >= 2 { return true }
        }
        return false
    }

    static func parseHexColor(_ s: String) -> ClipboardRGBColor? {
        guard s.hasPrefix("#") else { return nil }
        let body = String(s.dropFirst())
        let scalars = Array(body.unicodeScalars)
        guard scalars.allSatisfy({ ($0.value >= 48 && $0.value <= 57) || ($0.value >= 65 && $0.value <= 70) || ($0.value >= 97 && $0.value <= 102) }) else {
            return nil
        }
        func nibble(_ u: UnicodeScalar) -> UInt8 {
            switch u.value {
            case 48...57: return UInt8(u.value - 48)
            case 65...70: return UInt8(u.value - 55)
            default: return UInt8(u.value - 87)
            }
        }
        switch scalars.count {
        case 3:
            let r = nibble(scalars[0]) * 17
            let g = nibble(scalars[1]) * 17
            let b = nibble(scalars[2]) * 17
            return ClipboardRGBColor(r: r, g: g, b: b)
        case 6, 8:
            let r = (nibble(scalars[0]) << 4) | nibble(scalars[1])
            let g = (nibble(scalars[2]) << 4) | nibble(scalars[3])
            let b = (nibble(scalars[4]) << 4) | nibble(scalars[5])
            return ClipboardRGBColor(r: r, g: g, b: b)
        default:
            return nil
        }
    }
}

/// Bounded clipboard manager storing pinned snippets first and recent items second, with accent-insensitive
/// Vietnamese search, semantic classification, alias labeling, and cross-device iCloud merge helpers.
public struct ClipboardHistory: Sendable, Equatable {
    public static let maxPinned = 25
    public static let maxUnpinned = 25
    public static let maxItemUTF8Bytes = 8_192
    public static let maxCloudItemUTF8Bytes = 2_048

    public private(set) var items: [ClipboardItem]

    public init(items: [ClipboardItem] = []) {
        self.items = Self.normalize(items)
    }

    public init(serialized: [[String: String]]) {
        let parsed: [ClipboardItem] = serialized.compactMap { entry in
            guard let text = entry["text"], Self.isValidText(text) else { return nil }
            let alias = entry["alias"] ?? ""
            let pinned = entry["pinned"] == "1" || entry["pinned"] == "true"
            let ts = entry["ts"].flatMap(Int.init) ?? 0
            return ClipboardItem(text: text, alias: alias, isPinned: pinned, timestamp: ts)
        }
        self.items = Self.normalize(parsed)
    }

    public func serialized() -> [[String: String]] {
        items.map(Self.serializeEntry)
    }

    public var isEmpty: Bool { items.isEmpty }
    public var pinnedItems: [ClipboardItem] { items.filter(\.isPinned) }
    public var unpinnedItems: [ClipboardItem] { items.filter { !$0.isPinned } }

    @discardableResult
    public mutating func record(_ text: String, timestamp: Int = 0) -> Bool {
        guard Self.isValidText(text) else { return false }
        if let index = items.firstIndex(where: { $0.text == text }) {
            var existing = items.remove(at: index)
            existing.timestamp = max(existing.timestamp, timestamp)
            if existing.isPinned {
                items.insert(existing, at: 0)
            } else {
                let insertAt = items.firstIndex(where: { !$0.isPinned }) ?? items.count
                items.insert(existing, at: insertAt)
            }
        } else {
            let insertAt = items.firstIndex(where: { !$0.isPinned }) ?? items.count
            items.insert(ClipboardItem(text: text, isPinned: false, timestamp: timestamp), at: insertAt)
        }
        items = Self.normalize(items)
        return true
    }

    @discardableResult
    public mutating func addPinned(_ text: String, alias: String = "", timestamp: Int = 0) -> Bool {
        guard Self.isValidText(text) else { return false }
        let cleanAlias = ClipboardItem.sanitizeAlias(alias)
        if let index = items.firstIndex(where: { $0.text == text }) {
            var existing = items.remove(at: index)
            existing.isPinned = true
            if !cleanAlias.isEmpty { existing.alias = cleanAlias }
            existing.timestamp = max(existing.timestamp, timestamp)
            items.insert(existing, at: 0)
        } else {
            items.insert(ClipboardItem(text: text, alias: cleanAlias, isPinned: true, timestamp: timestamp), at: 0)
        }
        items = Self.normalize(items)
        return true
    }

    @discardableResult
    public mutating func updateItem(
        oldText: String,
        newText: String,
        alias: String,
        isPinned: Bool? = nil,
        timestamp: Int = 0
    ) -> Bool {
        guard Self.isValidText(newText),
              let index = items.firstIndex(where: { $0.text == oldText }) else { return false }
        var item = items.remove(at: index)
        item.text = newText
        item.alias = ClipboardItem.sanitizeAlias(alias)
        if let isPinned { item.isPinned = isPinned }
        item.timestamp = max(item.timestamp, timestamp)
        if newText != oldText {
            items.removeAll { $0.text == newText }
        }
        if item.isPinned {
            let insertAt = min(index, pinnedItems.count)
            items.insert(item, at: insertAt)
        } else {
            let firstUnpinned = items.firstIndex(where: { !$0.isPinned }) ?? items.count
            items.insert(item, at: firstUnpinned)
        }
        items = Self.normalize(items)
        return true
    }

    public mutating func movePinned(from sourceIndex: Int, to destinationIndex: Int) {
        var pinned = pinnedItems
        guard pinned.indices.contains(sourceIndex), pinned.indices.contains(destinationIndex),
              sourceIndex != destinationIndex else { return }
        let moved = pinned.remove(at: sourceIndex)
        pinned.insert(moved, at: destinationIndex)
        items = Self.normalize(pinned + unpinnedItems)
    }

    public mutating func togglePin(text: String) {
        guard let index = items.firstIndex(where: { $0.text == text }) else { return }
        var item = items.remove(at: index)
        item.isPinned.toggle()
        if item.isPinned {
            items.insert(item, at: 0)
        } else {
            let insertAt = items.firstIndex(where: { !$0.isPinned }) ?? items.count
            items.insert(item, at: insertAt)
        }
        items = Self.normalize(items)
    }

    public mutating func remove(text: String) {
        items.removeAll { $0.text == text }
    }

    public mutating func clearUnpinned() {
        items.removeAll { !$0.isPinned }
    }

    public mutating func clearAll() {
        items.removeAll()
    }

    /// Filters items by category and accent-insensitive Vietnamese query across both content and alias.
    public func filter(_ filter: ClipboardFilter, query: String = "") -> [ClipboardItem] {
        let base = search(query)
        guard filter != .all else { return base }
        return base.filter(filter.matches)
    }

    /// Searches clipboard items case-insensitively and accent-insensitively (`"viet nam"` matches `"Việt Nam"`).
    public func search(_ query: String) -> [ClipboardItem] {
        let trimmed = Self.trimWhitespace(query)
        guard !trimmed.isEmpty else { return items }
        let lowerQuery = trimmed.lowercased()
        let foldedQuery = TextConverter.stripVietnameseAccents(lowerQuery)
        return items.filter { item in
            Self.matchesQuery(item.text, lowerQuery: lowerQuery, foldedQuery: foldedQuery)
                || (!item.alias.isEmpty && Self.matchesQuery(item.alias, lowerQuery: lowerQuery, foldedQuery: foldedQuery))
        }
    }

    /// Returns a 1-tap Smart Paste suggestion when the user recently copied an OTP, URL, phone number, or email.
    public func smartPasteCandidate(
        pasteboardText: String? = nil,
        now: Int = 0,
        maxAgeSeconds: Int = 90
    ) -> ClipboardItem? {
        if let pasteboardText, Self.isValidText(pasteboardText) {
            let live = ClipboardItem(text: pasteboardText, isPinned: false, timestamp: now)
            if live.isSmartPasteCandidate { return live }
        }
        guard now > 0 else { return nil }
        return unpinnedItems.first { item in
            item.isSmartPasteCandidate
                && item.timestamp > 0
                && now >= item.timestamp
                && (now - item.timestamp) <= maxAgeSeconds
        }
    }

    public func cloudPinnedSerialized() -> [[String: String]] {
        pinnedItems
            .filter { $0.text.utf8.count <= Self.maxCloudItemUTF8Bytes }
            .map(Self.serializeEntry)
    }

    public func cloudRecentSerialized(limit: Int = 10) -> [[String: String]] {
        guard limit > 0 else { return [] }
        return Array(
            unpinnedItems
                .filter { $0.text.utf8.count <= Self.maxCloudItemUTF8Bytes }
                .prefix(limit)
        ).map(Self.serializeEntry)
    }

    public mutating func mergeCloud(pinned: [[String: String]], recent: [[String: String]]?) {
        var byText: [String: (item: ClipboardItem, order: Int)] = [:]
        for (idx, item) in items.enumerated() {
            byText[item.text] = (item, idx)
        }
        var nextOrder = items.count

        for entry in pinned {
            guard let text = entry["text"], Self.isValidText(text) else { continue }
            let alias = ClipboardItem.sanitizeAlias(entry["alias"] ?? "")
            let ts = entry["ts"].flatMap(Int.init) ?? 0
            if var existing = byText[text] {
                existing.item.isPinned = true
                if !alias.isEmpty && (existing.item.alias.isEmpty || ts >= existing.item.timestamp) {
                    existing.item.alias = alias
                }
                existing.item.timestamp = max(existing.item.timestamp, ts)
                byText[text] = existing
            } else {
                byText[text] = (ClipboardItem(text: text, alias: alias, isPinned: true, timestamp: ts), nextOrder)
                nextOrder += 1
            }
        }

        if let recent {
            for entry in recent {
                guard let text = entry["text"], Self.isValidText(text) else { continue }
                let alias = ClipboardItem.sanitizeAlias(entry["alias"] ?? "")
                let ts = entry["ts"].flatMap(Int.init) ?? 0
                if var existing = byText[text] {
                    if !alias.isEmpty && existing.item.alias.isEmpty {
                        existing.item.alias = alias
                    }
                    if ts > existing.item.timestamp {
                        existing.item.timestamp = ts
                        byText[text] = existing
                    }
                } else {
                    byText[text] = (ClipboardItem(text: text, alias: alias, isPinned: false, timestamp: ts), nextOrder)
                    nextOrder += 1
                }
            }
        }

        let sorted = byText.values.sorted { lhs, rhs in
            if lhs.item.isPinned != rhs.item.isPinned { return lhs.item.isPinned && !rhs.item.isPinned }
            if lhs.item.timestamp != rhs.item.timestamp { return lhs.item.timestamp > rhs.item.timestamp }
            return lhs.order < rhs.order
        }.map(\.item)
        items = Self.normalize(sorted)
    }

    private static func serializeEntry(_ item: ClipboardItem) -> [String: String] {
        var entry = [
            "text": item.text,
            "pinned": item.isPinned ? "1" : "0",
            "ts": String(item.timestamp),
        ]
        if !item.alias.isEmpty {
            entry["alias"] = item.alias
        }
        return entry
    }

    private static func isValidText(_ text: String) -> Bool {
        guard !text.isEmpty, text.utf8.count <= maxItemUTF8Bytes else { return false }
        return text.contains { !$0.isWhitespace && !$0.isNewline }
    }

    private static func normalize(_ raw: [ClipboardItem]) -> [ClipboardItem] {
        var seen = Set<String>()
        var pinned: [ClipboardItem] = []
        var unpinned: [ClipboardItem] = []
        for item in raw where isValidText(item.text) && seen.insert(item.text).inserted {
            if item.isPinned {
                pinned.append(item)
            } else {
                unpinned.append(item)
            }
        }
        return Array(pinned.prefix(maxPinned)) + Array(unpinned.prefix(maxUnpinned))
    }

    private static func trimWhitespace(_ s: String) -> String {
        String(s.drop(while: \.isWhitespace).reversed().drop(while: \.isWhitespace).reversed())
    }

    private static func matchesQuery(_ source: String, lowerQuery: String, foldedQuery: String) -> Bool {
        let lower = source.lowercased()
        if containsSubstring(lower, lowerQuery) { return true }
        let folded = TextConverter.stripVietnameseAccents(lower)
        return containsSubstring(folded, foldedQuery)
    }

    private static func containsSubstring(_ haystack: String, _ needle: String) -> Bool {
        guard !needle.isEmpty else { return true }
        return haystack.indices.contains { haystack[$0...].starts(with: needle) }
    }
}
