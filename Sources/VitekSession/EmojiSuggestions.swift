/// Pure-Swift on-device Vietnamese & English keyword-to-emoji lookup shared by macOS and iOS.
/// Zero external dependencies and deterministic O(1) dictionary lookup.
public enum EmojiSuggestions {
    public struct Category: Sendable, Equatable {
        public let title: String
        public let emojis: [String]
    }

    public static let categories: [Category] = [
        Category(title: "Cảm xúc", emojis: ["😀", "😂", "😊", "😍", "😘", "😎", "🤔", "😮", "😳", "😢", "😭", "😠", "😴", "🤒", "🥳", "❤️", "💔", "✨"]),
        Category(title: "Cử chỉ", emojis: ["👍", "👎", "👌", "🙏", "👏", "👋", "💪", "🤝", "✌️", "🤞", "🎉", "🔥", "⭐️", "✅", "❌", "⚠️", "💡", "🚀"]),
        Category(title: "Đồ ăn", emojis: ["☕️", "🍵", "🍺", "🧋", "🍚", "🍜", "🥖", "🍕", "🍔", "🎂", "🍰", "🍎", "🍊", "🍉", "🍓", "🌸", "☀️", "🌧️"]),
        Category(title: "Công việc", emojis: ["💻", "📱", "⌨️", "🖥️", "📧", "📅", "📝", "📌", "📎", "📁", "🔒", "🔑", "⚙️", "📊", "📈", "💰", "🎁", "🇻🇳"]),
    ]

    private static let singleWord: [String: String] = [
        // Reactions & emotions
        "haha": "😂", "hihi": "😆", "huhu": "😭", "lol": "😂",
        "cười": "😂", "cuoi": "😂",
        "vui": "😊", "happy": "😊",
        "buồn": "😢", "buon": "😢", "sad": "😢",
        "khóc": "😭", "khoc": "😭", "cry": "😭",
        "giận": "😠", "angry": "😠",
        "wow": "😮",
        "ngại": "😳", "shy": "😳",
        "mệt": "😫", "tired": "😫",
        "ngủ": "😴", "sleep": "😴",
        "ốm": "🤒", "sick": "🤒",
        "ngầu": "😎", "cool": "😎",
        "yêu": "❤️", "yeu": "❤️", "love": "❤️", "tim": "❤️", "heart": "❤️",
        "hôn": "😘", "kiss": "😘",

        // Gestures & status
        "ok": "👌", "okay": "👌",
        "like": "👍", "thích": "👍",
        "dislike": "👎",
        "thanks": "🙏", "tks": "🙏",
        "clap": "👏",
        "congrats": "🎉", "party": "🎉",
        "hello": "👋", "hi": "👋", "chào": "👋", "bye": "👋",
        "fighting": "💪",
        "done": "✅", "check": "✅",
        "warn": "⚠️",
        "star": "⭐️",
        "fire": "🔥", "cháy": "🔥", "hot": "🔥",
        "rocket": "🚀",
        "idea": "💡",
        "money": "💰",
        "gift": "🎁", "quà": "🎁",
        "cake": "🎂",

        // Daily life & food
        "cafe": "☕️", "coffee": "☕️",
        "trà": "🍵", "tea": "🍵",
        "bia": "🍺", "beer": "🍺",
        "phở": "🍜", "pho": "🍜", "noodle": "🍜",
        "pizza": "🍕",
        "hoa": "🌸", "flower": "🌸",
        "nắng": "☀️", "sun": "☀️",
        "mưa": "🌧️", "rain": "🌧️",
        "nhạc": "🎵", "music": "🎵",
        "sách": "📚", "book": "📚",
        "laptop": "💻",
        "phone": "📱",
        "flight": "✈️",
    ]

    private static let twoWord: [String: String] = [
        "cảm ơn": "🙏", "cam on": "🙏",
        "chúc mừng": "🎉", "chuc mung": "🎉",
        "vỗ tay": "👏", "vo tay": "👏",
        "cố lên": "💪", "co len": "💪",
        "tạm biệt": "👋", "tam biet": "👋",
        "xin chào": "👋", "xin chao": "👋",
        "sinh nhật": "🎂", "sinh nhat": "🎂",
        "cà phê": "☕️", "ca phe": "☕️",
        "bánh mì": "🥖", "banh mi": "🥖",
        "việt nam": "🇻🇳", "viet nam": "🇻🇳",
        "ý tưởng": "💡", "y tuong": "💡",
        "cảnh báo": "⚠️", "canh bao": "⚠️",
        "máy bay": "✈️", "may bay": "✈️",
        "máy tính": "💻", "may tinh": "💻",
        "điện thoại": "📱", "dien thoai": "📱",
        "ngạc nhiên": "😮", "ngac nhien": "😮",
    ]

    /// Returns an emoji candidate when the current word (`prefix`) or the immediately preceding
    /// 1–2 words (`before`) match a complete Vietnamese or English chat keyword.
    public static func match(before: [String], prefix: String) -> String? {
        if !prefix.isEmpty {
            guard prefix.count >= 2 else { return nil }
            return singleWord[prefix.lowercased()]
        }
        guard let last = before.last else { return nil }
        if before.count >= 2 {
            let pair = before[before.count - 2] + " " + last
            if let emoji = twoWord[pair] { return emoji }
        }
        return singleWord[last]
    }

    private static let searchableIndex: [(emoji: String, keywords: [String])] = {
        var keywordsByEmoji: [String: Set<String>] = [:]
        var orderedEmojis: [String] = []
        func register(_ emoji: String, _ rawKeyword: String) {
            if keywordsByEmoji[emoji] == nil {
                orderedEmojis.append(emoji)
                keywordsByEmoji[emoji] = []
            }
            let lower = rawKeyword.lowercased()
            let folded = TextConverter.stripVietnameseAccents(lower)
            keywordsByEmoji[emoji]?.insert(lower)
            keywordsByEmoji[emoji]?.insert(folded)
            for token in folded.split(separator: " ") where token.count >= 2 {
                keywordsByEmoji[emoji]?.insert(String(token))
            }
        }
        for category in categories {
            for emoji in category.emojis {
                register(emoji, category.title)
            }
        }
        for (kw, emoji) in singleWord { register(emoji, kw) }
        for (kw, emoji) in twoWord { register(emoji, kw) }
        let extraTags: [(String, String)] = [
            ("😀", "cuoi vui mặt cười smile"),
            ("😍", "yeu thich tim dang yeu"),
            ("🤔", "suy nghi nghi ngo think"),
            ("🥳", "chuc mung sinh nhat tiec party"),
            ("💔", "tan vo buon tim"),
            ("✨", "lap lanh dep sparkle"),
            ("👎", "khong thich che"),
            ("🤝", "bat tay hop tac deal"),
            ("✌️", "chien thang peace"),
            ("🤞", "may man hy vong luck"),
            ("❌", "sai huy xoa loi"),
            ("🧋", "tra sua bubble tea"),
            ("🍚", "com an trua an toi rice"),
            ("🍔", "banh burger do an nhanh"),
            ("🍰", "banh ngot kem"),
            ("🍎", "tao trai cay apple"),
            ("🍊", "cam quyt orange"),
            ("🍉", "dua hau watermelon"),
            ("🍓", "dau tay strawberry"),
            ("⌨️", "ban phim go phim keyboard"),
            ("🖥️", "man hinh may tinh"),
            ("📧", "thu email mail"),
            ("📅", "lich hen ngay calendar"),
            ("📝", "ghi chu viet note"),
            ("📌", "ghim quan trong pin"),
            ("🔒", "khoa bao mat lock"),
            ("🔑", "chia khoa mat khau key"),
            ("⚙️", "cai dat tuy chinh settings"),
            ("📊", "bieu do bao cao chart"),
            ("📈", "tang truong chung khoan"),
        ]
        for (emoji, tags) in extraTags { register(emoji, tags) }
        return orderedEmojis.map { ($0, Array(keywordsByEmoji[$0] ?? [])) }
    }()

    /// Searches emojis by accented or unaccented Vietnamese/English keyword prefix or substring.
    public static func search(_ query: String, limit: Int = 18) -> [String] {
        let trimmed = String(query.drop(while: \.isWhitespace).reversed().drop(while: \.isWhitespace).reversed())
        guard !trimmed.isEmpty else { return [] }
        let lower = trimmed.lowercased()
        let folded = TextConverter.stripVietnameseAccents(lower)
        guard !folded.isEmpty else { return [] }

        var exactMatches: [String] = []
        if let primary = twoWord[lower] ?? twoWord[folded] ?? singleWord[lower] ?? singleWord[folded] {
            exactMatches.append(primary)
        }

        var prefixMatches: [String] = []
        var substringMatches: [String] = []
        for entry in searchableIndex where !exactMatches.contains(entry.emoji) {
            if entry.keywords.contains(where: { $0.hasPrefix(folded) }) {
                prefixMatches.append(entry.emoji)
            } else if entry.keywords.contains(where: { $0.contains(folded) }) {
                substringMatches.append(entry.emoji)
            }
        }
        return Array((exactMatches + prefixMatches + substringMatches).prefix(limit))
    }
}
