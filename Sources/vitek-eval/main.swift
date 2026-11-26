import Foundation
import VitekEngine
import VitekSession

// Reproducible accuracy & quality evaluation suite for viTek (`swift run -c release vitek-eval`).
// Evaluates three core pillars without external network or platform dependencies:
//   1. Vietnamese Telex/VNI orthography, delayed marks, Quick Telex (`viw`/`yw`/`uyw`), and `uô ↔ ươ` switching.
//   2. Bilingual Vietnamese-English code-switching, technical tokens, and ANE `LanguageContextHint` disambiguation.
//   3. Long-range semantic domain reranking (`SemanticRanker` + `WordPrediction`) and smart shortcut mining.

struct TypingCase {
    let name: String
    let keys: String
    let expected: String
    var options: EngineOptions = EngineOptions()
    var contextHint: ContextLanguageHint = .automatic
}

func typeSequence(_ input: String, options: EngineOptions = EngineOptions(), contextHint: ContextLanguageHint = .automatic) -> String {
    var engine = VitekEngine(options: options)
    engine.contextHint = contextHint
    var session = InputSession(engine: engine)
    var buffer = ""
    var marked: String?

    for ch in input {
        let isBoundary = ch == " " || ch == "." || ch == "," || ch == ":" || ch == "/" || ch == "-" || ch == "_"
        let output = session.handle(isBoundary ? .boundary : .character(ch))
        if isBoundary {
            // Re-apply test-level contextHint across word boundaries when explicitly specified
            if contextHint != .automatic {
                session.engine.contextHint = contextHint
            }
        }
        for cmd in output.commands {
            switch cmd {
            case .insert(let text):
                marked = nil
                buffer += text
            case .mark(let text):
                marked = text
            }
        }
        if output.passThrough {
            if let currentMarked = marked {
                buffer += currentMarked
                marked = nil
            }
            buffer.append(ch)
        }
    }
    let tail = session.handle(.boundary)
    for cmd in tail.commands {
        if case .insert(let text) = cmd {
            marked = nil
            buffer += text
        }
    }
    if let currentMarked = marked {
        buffer += currentMarked
    }
    return buffer
}

var quickWOptions = EngineOptions()
quickWOptions.quickTelexW = true

var traditionalOptions = EngineOptions()
traditionalOptions.toneStyle = .traditional

var vniOptions = EngineOptions(inputMethod: .vni)

let orthographyCases: [TypingCase] = [
    // Core Telex & delayed marks
    TypingCase(name: "telex_standard_sentence", keys: "Tooi yeeu tieengs Vieetj Nam", expected: "Tôi yêu tiếng Việt Nam"),
    TypingCase(name: "telex_delayed_marks", keys: "nguoifw khuyeenr nghieeng giuwax", expected: "người khuyển nghiêng giữa"),
    TypingCase(name: "telex_delayed_uo_compound", keys: "chuowngf trinhf dduwowcj thuwjc hieenj", expected: "chường trình được thực hiện"),
    TypingCase(name: "telex_qu_gi_clusters", keys: "quar giar quyeets gieengs", expected: "quả giả quyết giếng"),
    TypingCase(name: "telex_modern_tone", keys: "hoaf khoer thuys tuys", expected: "hoà khoẻ thuý tuý"),
    TypingCase(name: "telex_traditional_tone", keys: "hoaf khoer thuys", expected: "hòa khỏe thúy", options: traditionalOptions),
    // Smooth bidirectional compound vowel transitions (uô ↔ ươ, ă ↔ â)
    TypingCase(name: "switch_uo_to_uow_tuong", keys: "tuoongw", expected: "tương"),
    TypingCase(name: "switch_uo_to_uow_with_tone", keys: "muooiwf buoonfw", expected: "mười bườn"),
    TypingCase(name: "switch_uow_to_uo_tuong", keys: "tuowngo", expected: "tuông"),
    TypingCase(name: "switch_uow_to_uo_with_tone", keys: "muowifo duowcjo", expected: "muồi duộc"),
    TypingCase(name: "switch_aw_aa_bidirectional", keys: "trawnga traangw", expected: "trâng trăng"),
    // High-speed 100+ WPM transposition recovery + English protection
    TypingCase(name: "typo_recovery_coda_gn_hn_hc", keys: "tieegns dduowgnf mihnf chihns thihcs bahcj", expected: "tiếng đường mình chính thích bạch"),
    TypingCase(name: "typo_recovery_glide_uoi", keys: "nguwiof nguiowf muwiof", expected: "người người mười"),
    TypingCase(name: "typo_recovery_english_safe", keys: "signs designs reigns foreign john", expected: "signs designs reigns foreign john"),
    // Quick Telex W: iê, yê, uyê + double-w undo
    TypingCase(name: "quick_telex_ie", keys: "viwtj tiwngs kiwmr", expected: "việt tiếng kiểm", options: quickWOptions),
    TypingCase(name: "quick_telex_ye_uye", keys: "ywus ywn quywts chuywnj nguywnx tuywts", expected: "yếu yên quyết chuyện nguyễn tuyết", options: quickWOptions),
    TypingCase(name: "quick_telex_undo_ww", keys: "viww yww chuyww", expected: "viw yw chuyw", options: quickWOptions),
    // Double-key undo & tone replacement
    TypingCase(name: "telex_double_undo", keys: "vieetjj tooo ddd tuyss", expected: "viêtj too dd tuys"),
    TypingCase(name: "telex_tone_override_and_z", keys: "tooisrfz tooisj", expected: "tôi tội"),
    // VNI orthography
    TypingCase(name: "vni_sentence", keys: "Tie61ng Vie65t ra61t muo75t ma2", expected: "Tiếng Việt rất mượt mà", options: vniOptions),
    TypingCase(name: "vni_clusters", keys: "Truo72ng D9a5i ho5c Ba1ch khoa Ha2 No65i", expected: "Trường Đại học Bách khoa Hà Nội", options: vniOptions),
]

let bilingualCases: [TypingCase] = [
    TypingCase(name: "mixed_devops_sentence", keys: "reset server vaf check docker container nhes", expected: "reset server và check docker container nhé"),
    TypingCase(name: "mixed_git_workflow", keys: "review pull request treen github truwowcs khi deploy", expected: "review pull request trên github trước khi deploy"),
    TypingCase(name: "identifier_camelcase_preserved", keys: "bieens userName vaf parseRequestData giuwx nguyeen", expected: "biến userName và parseRequestData giữ nguyên"),
    TypingCase(name: "url_and_path_preserved", keys: "https://github.com/luongbinhf/viTek", expected: "https://github.com/luongbinhf/viTek"),
    TypingCase(name: "english_words_with_mark_letters", keys: "server express browser window raw format", expected: "server express browser window raw format"),
    // ANE Context Hint disambiguation: English context keeps ambiguous words raw
    TypingCase(name: "ane_english_hint_ambiguous_words", keys: "max tax bus box mix six raw has see", expected: "max tax bus box mix six raw has see", contextHint: .english),
    // ANE Context Hint disambiguation: Vietnamese context composes Vietnamese syllables normally
    TypingCase(name: "ane_vietnamese_hint_syllables", keys: "mas tas hoor ddi lafm sowms", expected: "má tá hổ đi làm sớm", contextHint: .vietnamese),
    // Explicit override `tets` still produces `tét` while `test` stays `test`
    TypingCase(name: "test_vs_tets_intent", keys: "chayj test xong rooif tets thuwr", expected: "chạy test xong rồi tét thử"),
]

struct RankingCase {
    let name: String
    let context: String
    let prefix: String
    let expectedInTop3: String
}

let rankingCases: [RankingCase] = [
    RankingCase(
        name: "domain_tech_long_range",
        context: "Hệ thống máy chủ cơ sở dữ liệu đám mây đang cần kiểm thử bảo mật, nên hôm nay nhóm sẽ viết tài ",
        prefix: "l",
        expectedInTop3: "liệu"
    ),
    RankingCase(
        name: "domain_business_contract",
        context: "Phòng kế toán đang đối chiếu hóa đơn doanh thu và rà soát hợp ",
        prefix: "đ",
        expectedInTop3: "đồng"
    ),
    RankingCase(
        name: "domain_health_hospital",
        context: "Bác sĩ khám lâm sàng xét nghiệm máu tại bệnh ",
        prefix: "v",
        expectedInTop3: "viện"
    ),
    RankingCase(
        name: "domain_education_university",
        context: "Sinh viên đại học nghiên cứu tài liệu và bảo vệ luận ",
        prefix: "v",
        expectedInTop3: "văn"
    ),
    RankingCase(
        name: "phrase_tri_tue_nhan_tao",
        context: "Ứng dụng mô hình trí tuệ nhân ",
        prefix: "",
        expectedInTop3: "tạo"
    ),
    RankingCase(
        name: "phrase_co_so_du_lieu",
        context: "Sao lưu hệ thống cơ sở dữ ",
        prefix: "",
        expectedInTop3: "liệu"
    ),
]

struct SuiteReport: Codable {
    let suite: String
    let passed: Int
    let total: Int
    let accuracyPercent: Double
    let failures: [String]
}

func runTypingSuite(name: String, cases: [TypingCase]) -> SuiteReport {
    var passed = 0
    var failures: [String] = []
    for item in cases {
        let actual = typeSequence(item.keys, options: item.options, contextHint: item.contextHint)
        if actual == item.expected {
            passed += 1
        } else {
            failures.append("\(item.name): expected '\(item.expected)', got '\(actual)'")
        }
    }
    let pct = cases.isEmpty ? 100.0 : (Double(passed) / Double(cases.count)) * 100.0
    return SuiteReport(suite: name, passed: passed, total: cases.count, accuracyPercent: pct, failures: failures)
}

func runRankingSuite() -> (report: SuiteReport, top1Count: Int) {
    var passedTop3 = 0
    var passedTop1 = 0
    var failures: [String] = []
    for item in rankingCases {
        let candidates = WordPrediction.suggest(context: item.context + item.prefix, prefix: item.prefix, limit: 5)
        let top3 = candidates.prefix(3).map { $0.text.lowercased() }
        let target = item.expectedInTop3.lowercased()
        if top3.first == target {
            passedTop1 += 1
        }
        if top3.contains(target) {
            passedTop3 += 1
        } else {
            failures.append("\(item.name): expected '\(item.expectedInTop3)' in top-3, got \(top3)")
        }
    }

    // Also verify SemanticRanker domain classification & PersonalFrequency shortcut mining
    let techDomain = SemanticRanker.inferDomain(from: "triển khai server docker database api mã nguồn mở")
    let bizDomain = SemanticRanker.inferDomain(from: "chuyển khoản ngân hàng thanh toán hóa đơn thuế doanh thu")
    var memory = PersonalFrequency()
    for _ in 0..<5 {
        memory.record(word: "ơn", after: "cảm")
        memory.record(word: "bạn", after: "ơn", beforeThat: "cảm")
    }
    let mined = memory.suggestedShortcuts(minCount: 4, limit: 3)

    var extraChecks = 0
    let extraTotal = 3
    if techDomain == .technology { extraChecks += 1 } else { failures.append("semantic_domain_tech: got \(String(describing: techDomain))") }
    if bizDomain == .business { extraChecks += 1 } else { failures.append("semantic_domain_biz: got \(String(describing: bizDomain))") }
    if mined.contains(where: { $0.abbreviation == "cob" && $0.phrase == "cảm ơn bạn" }) {
        extraChecks += 1
    } else {
        failures.append("shortcut_mining_cob: missing expected 'cob -> cảm ơn bạn'")
    }

    let total = rankingCases.count + extraTotal
    let passed = passedTop3 + extraChecks
    let pct = (Double(passed) / Double(total)) * 100.0
    return (SuiteReport(suite: "semantic_and_mining", passed: passed, total: total, accuracyPercent: pct, failures: failures), passedTop1)
}

let orthographyReport = runTypingSuite(name: "orthography_telex_vni", cases: orthographyCases)
let bilingualReport = runTypingSuite(name: "bilingual_codeswitch", cases: bilingualCases)
let (rankingReport, top1Hits) = runRankingSuite()
let allReports = [orthographyReport, bilingualReport, rankingReport]

if CommandLine.arguments.contains("--json") {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(allReports)
    print(String(decoding: data, as: UTF8.self))
} else {
    print("viTek Evaluation Suite")
    print("======================")
    for report in allReports {
        let label = report.suite.padding(toLength: 24, withPad: " ", startingAt: 0)
        print("• \(label) \(String(format: "%2d/%-2d (%6.2f%%)", report.passed, report.total, report.accuracyPercent))")
        for failure in report.failures {
            print("    ✗ \(failure)")
        }
    }
    let top1Label = "ranking_top1".padding(toLength: 24, withPad: " ", startingAt: 0)
    print("• \(top1Label) \(String(format: "%2d/%-2d (Top-1 hits)", top1Hits, rankingCases.count))")
}

let allPassed = orthographyReport.accuracyPercent == 100.0
    && bilingualReport.accuracyPercent >= 98.0
    && rankingReport.accuracyPercent >= 90.0

if !allPassed {
    Foundation.exit(1)
}
