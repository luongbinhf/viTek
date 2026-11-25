import VitekEngine

/// Pure-Swift long-range semantic topic ranker and concept-aware clipboard matcher.
/// Runs with zero allocations on unactivated contexts and never invents unverified words.
public enum SemanticRanker {
    public enum Topic: String, Sendable, CaseIterable {
        case bankingFinance
        case legalContract
        case softwareEngineering
        case scheduleMeeting
        case addressLogistics
        case healthCare
        case educationScience
    }

    private struct TopicProfile: Sendable {
        let topic: Topic
        let contextCues: Set<String>
        let boostedWords: Set<String>
        let clipboardQueryCues: Set<String>
        let clipboardContentMarkers: Set<String>
    }

    private static let profiles: [TopicProfile] = [
        TopicProfile(
            topic: .bankingFinance,
            contextCues: [
                "ngan", "hang", "chuyen", "khoan", "thanh", "toan", "hoa", "don", "thue",
                "doanh", "thu", "loi", "nhuan", "tai", "chinh", "tien", "phi", "quy",
                "vcb", "tcb", "mb", "acb", "bidv", "vietcombank", "techcombank", "stk", "banking", "invoice",
            ],
            boostedWords: [
                "khoản", "toán", "hàng", "chính", "thuế", "tiền", "phí", "vốn", "lãi", "quỹ", "đơn", "số",
            ],
            clipboardQueryCues: [
                "ngan hang", "chuyen khoan", "tai khoan", "stk", "thanh toan", "so tk", "bank", "hoa don",
            ],
            clipboardContentMarkers: [
                "vcb", "vietcombank", "techcombank", "tcb", "bidv", "vietinbank", "acb", "mbbank", "vpbank",
                "tpbank", "momo", "zalopay", "stk", "tai khoan", "ngan hang", "iban", "swift",
            ]
        ),
        TopicProfile(
            topic: .legalContract,
            contextCues: [
                "hop", "dong", "thue", "phap", "luat", "ky", "ket", "thoa", "thuan",
                "tranh", "chap", "trach", "nhiem", "quyen", "ben", "cam", "bien", "ban",
                "contract", "legal", "policy", "terms",
            ],
            boostedWords: [
                "khoản", "điều", "nghĩa", "vụ", "quyền", "hợp", "đồng", "luật", "pháp", "trách", "nhiệm", "bên",
            ],
            clipboardQueryCues: [
                "hop dong", "phap ly", "dieu khoan", "ma so thue", "mst", "cong ty", "xuat hoa don",
            ],
            clipboardContentMarkers: [
                "mst", "ma so thue", "cong ty", "tnhh", "co phan", "hop dong", "dai dien", "giay phep",
            ]
        ),
        TopicProfile(
            topic: .softwareEngineering,
            contextCues: [
                "he", "thong", "may", "chu", "co", "so", "du", "lieu", "ma", "nguon",
                "kiem", "thu", "trien", "khai", "ung", "dung", "thuat", "toan", "mang",
                "server", "deploy", "build", "api", "bug", "log", "prod", "staging", "docker", "git", "swift",
            ],
            boostedWords: [
                "thống", "liệu", "mật", "nguồn", "thử", "khai", "mạng", "chủ", "phiên", "bản", "lỗi", "tốc", "độ", "bộ", "nhớ",
            ],
            clipboardQueryCues: [
                "lenh", "terminal", "shell", "code", "ma nguon", "deploy", "git", "server", "api", "token",
            ],
            clipboardContentMarkers: [
                "git ", "brew ", "swift ", "docker ", "npm ", "curl ", "ssh ", "https://api", "localhost", "func ", "struct ",
            ]
        ),
        TopicProfile(
            topic: .scheduleMeeting,
            contextCues: [
                "lich", "hop", "hen", "gap", "cuoc", "phong", "thoi", "gian", "buoi",
                "sang", "chieu", "toi", "tuan", "thang", "deadline", "meeting", "zoom", "call",
            ],
            boostedWords: [
                "họp", "hẹn", "gian", "sáng", "chiều", "tối", "tuần", "ngày", "phòng", "lịch", "trình",
            ],
            clipboardQueryCues: [
                "lich hop", "zoom", "meet", "cuoc hop", "hen gap",
            ],
            clipboardContentMarkers: [
                "zoom.us", "meet.google", "teams.microsoft", "lich hop", "phong hop",
            ]
        ),
        TopicProfile(
            topic: .addressLogistics,
            contextCues: [
                "dia", "chi", "giao", "nhan", "van", "chuyen", "toa", "nha", "tang",
                "phuong", "quan", "duong", "thanh", "pho", "ship", "buu", "cuc",
            ],
            boostedWords: [
                "chỉ", "hàng", "chuyển", "nhà", "tầng", "quận", "phường", "đường", "phố",
            ],
            clipboardQueryCues: [
                "dia chi", "giao hang", "van phong", "nha rieng", "ship", "vi tri",
            ],
            clipboardContentMarkers: [
                "tang ", "toa nha", "phuong ", "quan ", "duong ", "tp.", "tp ", "ha noi", "ho chi minh", "hcm", "da nang", "so ",
            ]
        ),
        TopicProfile(
            topic: .healthCare,
            contextCues: [
                "suc", "khoe", "benh", "vien", "bac", "si", "thuoc", "kham", "dieu", "tri", "trieu", "chung",
            ],
            boostedWords: [
                "trị", "khỏe", "bệnh", "viện", "thuốc", "khám", "chứng", "dưỡng",
            ],
            clipboardQueryCues: [
                "benh vien", "don thuoc", "suc khoe", "bao hiem",
            ],
            clipboardContentMarkers: [
                "benh vien", "phong kham", "bac si", "bhyt", "don thuoc",
            ]
        ),
        TopicProfile(
            topic: .educationScience,
            contextCues: [
                "nghien", "cuu", "khoa", "hoc", "giao", "duc", "sinh", "vien", "giang", "truong", "dai", "bai", "thi",
            ],
            boostedWords: [
                "cứu", "học", "viên", "trường", "giáo", "dục", "luận", "nghiệm",
            ],
            clipboardQueryCues: [
                "truong hoc", "sinh vien", "tai lieu", "nghien cuu",
            ],
            clipboardContentMarkers: [
                "dai hoc", "hoc vien", "mssv", "giao trinh", "luan van",
            ]
        ),
    ]

    /// Reranks verified prose candidates using long-range sentence topic cues (up to 20 words before cursor).
    /// Only activates when broader context outside the immediate trailing word carries >= 2 topic signals,
    /// leaving short/neutral phrases and shortcut expansions untouched.
    public static func rerank(
        _ candidates: [WordCandidate],
        sentenceContext: String,
        prefix: String
    ) -> [WordCandidate] {
        guard candidates.count > 1 else { return candidates }
        let before = String(sentenceContext.dropLast(min(prefix.count, sentenceContext.count)))
        let foldedTokens = extractFoldedSentenceTokens(from: before, limit: 20)
        // Require broader context beyond a single preceding word so standard bigrams remain unchanged.
        guard foldedTokens.count >= 3 else { return candidates }
        let widerTokens = Array(foldedTokens.dropLast())

        var topicScores: [Topic: Int] = [:]
        for profile in profiles {
            var hits = 0
            for token in widerTokens where profile.contextCues.contains(token) {
                hits += 1
            }
            if hits >= 2 {
                topicScores[profile.topic] = hits
            }
        }
        guard !topicScores.isEmpty else { return candidates }

        return candidates.map { candidate in
            // Never alter explicit shortcut expansions (score >= 2_100) or emoji.
            guard candidate.score < 2_100, candidate.source != .emoji else { return candidate }
            let lowerCandidate = candidate.text.lowercased()
            var bonus = 0
            for profile in profiles {
                guard let hits = topicScores[profile.topic],
                      profile.boostedWords.contains(lowerCandidate) else { continue }
                bonus = max(bonus, min(360, 140 + hits * 45))
            }
            guard bonus > 0 else { return candidate }
            return WordCandidate(
                text: candidate.text,
                source: candidate.source,
                score: candidate.score + bonus,
                appendsSpace: candidate.appendsSpace
            )
        }.sorted {
            if $0.score != $1.score { return $0.score > $1.score }
            return $0.text < $1.text
        }
    }

    /// Infers the dominant `VocabularyDomain` from broader sentence tokens when no external ANE model is active.
    public static func inferDomain(from context: String) -> VocabularyDomain? {
        let tokens = extractFoldedSentenceTokens(from: context, limit: 20)
        guard tokens.count >= 2 else { return nil }
        var bestTopic: Topic?
        var bestHits = 1
        for profile in profiles {
            var hits = 0
            for t in tokens where profile.contextCues.contains(t) { hits += 1 }
            if hits > bestHits {
                bestHits = hits
                bestTopic = profile.topic
            }
        }
        switch bestTopic {
        case .softwareEngineering: return .technology
        case .bankingFinance, .legalContract, .scheduleMeeting, .addressLogistics: return .business
        case .healthCare: return .health
        case .educationScience: return .education
        case nil: return nil
        }
    }

    /// Concept-level semantic matching for Clipboard items so Vietnamese intent queries find matching snippets
    /// even without literal substring overlap (e.g. `"ma xac nhan"` -> OTP, `"chuyen khoan"` -> bank account,
    /// `"dia chi giao hang"` -> street/ward/floor snippet).
    public static func matchesClipboardConcept(item: ClipboardItem, foldedQuery: String) -> Bool {
        guard foldedQuery.count >= 2 else { return false }

        // 1) Semantic content-kind intents
        let otpQueries = ["otp", "ma xac nhan", "ma xac thuc", "ma so", "2fa", "code xac nhan"]
        if item.kind == .otp, otpQueries.contains(where: { contains(foldedQuery, $0) || contains($0, foldedQuery) && foldedQuery.count >= 3 }) {
            return true
        }

        let phoneQueries = ["sdt", "so dien thoai", "dien thoai", "hotline", "lien he", "goi dien"]
        if item.kind == .phone, phoneQueries.contains(where: { contains(foldedQuery, $0) }) {
            return true
        }

        let emailQueries = ["email", "thu dien tu", "hom thu", "mail"]
        if item.kind == .email, emailQueries.contains(where: { contains(foldedQuery, $0) }) {
            return true
        }

        let urlQueries = ["link", "lien ket", "trang web", "website", "url", "duong dan"]
        if item.kind == .url, urlQueries.contains(where: { contains(foldedQuery, $0) }) {
            return true
        }

        let colorQueries = ["mau", "ma mau", "hex", "color", "bang mau"]
        if item.kind == .hexColor, colorQueries.contains(where: { contains(foldedQuery, $0) }) {
            return true
        }

        let codeQueries = ["code", "lenh", "terminal", "shell", "script", "ma nguon"]
        if item.kind == .code, codeQueries.contains(where: { contains(foldedQuery, $0) }) {
            return true
        }

        // 2) Topic concept expansion between query intent and item body/alias
        let foldedBody = TextConverter.stripVietnameseAccents((item.alias + " " + item.text).lowercased())
        for profile in profiles {
            let queryMatchesTopic = profile.clipboardQueryCues.contains { cue in
                contains(foldedQuery, cue) || (foldedQuery.count >= 4 && contains(cue, foldedQuery))
            }
            guard queryMatchesTopic else { continue }
            if profile.clipboardContentMarkers.contains(where: { contains(foldedBody, $0) }) {
                return true
            }
            // Bank account heuristic: query asks for bank/account and item has 8-19 contiguous digits
            if profile.topic == .bankingFinance, hasAccountDigits(in: item.text) {
                return true
            }
        }

        return false
    }

    private static func extractFoldedSentenceTokens(from text: String, limit: Int) -> [String] {
        var boundary = text.endIndex
        while boundary > text.startIndex {
            let prev = text.index(before: boundary)
            let ch = text[prev]
            if ch == "." || ch == "!" || ch == "?" || ch == "\n" || ch == ";" {
                break
            }
            boundary = prev
        }
        let clause = text[boundary...]
        let rawWords = clause.split { !$0.isLetter && !$0.isNumber }
        return rawWords.suffix(limit).map {
            TextConverter.stripVietnameseAccents(String($0).lowercased())
        }
    }

    private static func hasAccountDigits(in text: String) -> Bool {
        var run = 0
        for ch in text {
            if ch.isASCII && ch.isNumber {
                run += 1
                if run >= 8 { return true }
            } else if ch != " " && ch != "-" {
                run = 0
            }
        }
        return false
    }

    private static func contains(_ haystack: String, _ needle: String) -> Bool {
        guard !needle.isEmpty else { return true }
        return haystack.indices.contains { haystack[$0...].starts(with: needle) }
    }
}
