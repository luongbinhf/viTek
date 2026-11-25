/// Pure-Swift clipboard item and history store shared by macOS and iOS without Foundation.
public struct ClipboardItem: Sendable, Equatable {
    public var text: String
    public var isPinned: Bool
    public var timestamp: Int

    public init(text: String, isPinned: Bool = false, timestamp: Int = 0) {
        self.text = text
        self.isPinned = isPinned
        self.timestamp = timestamp
    }

    /// Collapses contiguous whitespace/newlines and truncates long snippets for compact menus/popups.
    public var preview: String {
        let collapsed = text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        if collapsed.count <= 80 { return collapsed }
        return String(collapsed.prefix(79)) + "…"
    }
}

/// Bounded clipboard manager storing pinned snippets first and recent items second, with accent-insensitive
/// Vietnamese search and cross-device iCloud merge helpers.
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
            let pinned = entry["pinned"] == "1" || entry["pinned"] == "true"
            let ts = entry["ts"].flatMap(Int.init) ?? 0
            return ClipboardItem(text: text, isPinned: pinned, timestamp: ts)
        }
        self.items = Self.normalize(parsed)
    }

    public func serialized() -> [[String: String]] {
        items.map { item in
            [
                "text": item.text,
                "pinned": item.isPinned ? "1" : "0",
                "ts": String(item.timestamp),
            ]
        }
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
    public mutating func addPinned(_ text: String, timestamp: Int = 0) -> Bool {
        guard Self.isValidText(text) else { return false }
        if let index = items.firstIndex(where: { $0.text == text }) {
            var existing = items.remove(at: index)
            existing.isPinned = true
            existing.timestamp = max(existing.timestamp, timestamp)
            items.insert(existing, at: 0)
        } else {
            items.insert(ClipboardItem(text: text, isPinned: true, timestamp: timestamp), at: 0)
        }
        items = Self.normalize(items)
        return true
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

    /// Searches clipboard items case-insensitively and accent-insensitively (`"viet nam"` matches `"Việt Nam"`).
    public func search(_ query: String) -> [ClipboardItem] {
        let trimmed = Self.trimWhitespace(query)
        guard !trimmed.isEmpty else { return items }
        let lowerQuery = trimmed.lowercased()
        let foldedQuery = TextConverter.stripVietnameseAccents(lowerQuery)
        return items.filter { item in
            let lowerText = item.text.lowercased()
            if Self.containsSubstring(lowerText, lowerQuery) { return true }
            let foldedText = TextConverter.stripVietnameseAccents(lowerText)
            return Self.containsSubstring(foldedText, foldedQuery)
        }
    }

    public func cloudPinnedSerialized() -> [[String: String]] {
        pinnedItems
            .filter { $0.text.utf8.count <= Self.maxCloudItemUTF8Bytes }
            .map { ["text": $0.text, "pinned": "1", "ts": String($0.timestamp)] }
    }

    public func cloudRecentSerialized(limit: Int = 10) -> [[String: String]] {
        guard limit > 0 else { return [] }
        return Array(
            unpinnedItems
                .filter { $0.text.utf8.count <= Self.maxCloudItemUTF8Bytes }
                .prefix(limit)
        ).map { ["text": $0.text, "pinned": "0", "ts": String($0.timestamp)] }
    }

    public mutating func mergeCloud(pinned: [[String: String]], recent: [[String: String]]?) {
        var byText: [String: (item: ClipboardItem, order: Int)] = [:]
        for (idx, item) in items.enumerated() {
            byText[item.text] = (item, idx)
        }
        var nextOrder = items.count

        for entry in pinned {
            guard let text = entry["text"], Self.isValidText(text) else { continue }
            let ts = entry["ts"].flatMap(Int.init) ?? 0
            if var existing = byText[text] {
                existing.item.isPinned = true
                existing.item.timestamp = max(existing.item.timestamp, ts)
                byText[text] = existing
            } else {
                byText[text] = (ClipboardItem(text: text, isPinned: true, timestamp: ts), nextOrder)
                nextOrder += 1
            }
        }

        if let recent {
            for entry in recent {
                guard let text = entry["text"], Self.isValidText(text) else { continue }
                let ts = entry["ts"].flatMap(Int.init) ?? 0
                if var existing = byText[text] {
                    if ts > existing.item.timestamp {
                        existing.item.timestamp = ts
                        byText[text] = existing
                    }
                } else {
                    byText[text] = (ClipboardItem(text: text, isPinned: false, timestamp: ts), nextOrder)
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

    private static func containsSubstring(_ haystack: String, _ needle: String) -> Bool {
        guard !needle.isEmpty else { return true }
        return haystack.indices.contains { haystack[$0...].starts(with: needle) }
    }
}
