/// Bounded preferences, updated only by finished words with an identifiable reading.
/// These two scores are all the macOS host persists for each application.
public struct TypingHabits: Equatable, Sendable {
    public enum Evidence: Sendable { case telex, vni, english }
    public private(set) var telexScore: Int
    public private(set) var vniScore: Int

    public init(telexScore: Int = 0, vniScore: Int = 0) {
        self.telexScore = Self.bounded(telexScore)
        self.vniScore = Self.bounded(vniScore)
    }

    private static func bounded(_ score: Int) -> Int { max(-3, min(3, score)) }

    public mutating func observe(_ evidence: Evidence) {
        telexScore = Self.bounded(telexScore + (evidence == .telex ? 1 : -1))
        vniScore = Self.bounded(vniScore + (evidence == .vni ? 1 : -1))
    }

    // These short spellings are common Telex for cả, hẻ, ì, sẽ, ứa.
    static let needsEnglishContext: Set<String> = ["car", "her", "if", "sex", "was"]
    static let vietnameseCues: Set<String> = [
        "anh", "chao", "chua", "chuyen", "cung", "dang", "duoc", "khi", "khong", "luon",
        "minh", "ngay", "nghe", "nguoi", "nhau", "nhieu", "nhung", "sinh", "theo", "thi",
        "thoi", "trong", "truoc", "vay", "xem",
    ]
    static let ambiguous = needsEnglishContext.union([
        "as", "is", "of", "or", "us", "has", "his", "its", "low", "how", "now", "row", "too",
        "been", "soon", "noon", "teen", "own", "room", "see", "moon", "this", "more", "there", "here", "these", "does", "days", "those",
    ])
    // Common English words that collide with valid Telex syllables in mixed technical/office sentences
    // (e.g. bus/bú, max/mã, tax/tã, box/bõ, mix/mĩ, six/sĩ, bar/bả, thus/thú). Kept literal only when
    // preceded by English or when the host's ANE context classifier signals English context.
    static let codeSwitchAmbiguous: Set<String> = [
        "bus", "gas", "tax", "max", "box", "mix", "six", "bar", "tar", "nor", "sir",
        "bow", "tow", "sow", "vow", "thus", "ways", "rows",
    ]
    static let englishCues: Set<String> = [
        "the", "with", "from", "and", "hello", "server", "express", "data",
        "www", "issue", "issues", "class", "address", "message", "lose",
        "core", "sore", "bore", "tore", "chore",
        "nose", "rose", "pose", "dose", "hose", "horse",
        "door", "poor", "loser", "virus", "versus",
        "user", "users", "browser", "folder", "filter", "render", "header", "footer", "router", "docker",
    ]

    // A1 might be a cell reference or VNI for Á. Leave it literal on a fresh profile.
    static func resemblesCellReference(_ keys: [Character]) -> Bool {
        guard (2...4).contains(keys.count), let last = keys.last, "12345".contains(last) else { return false }
        return keys.dropLast().allSatisfy { $0.isASCII && $0.isUppercase }
    }
}
