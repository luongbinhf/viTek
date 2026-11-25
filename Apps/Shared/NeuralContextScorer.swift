import CoreML
import Foundation
import NaturalLanguage
import VitekEngine
import VitekSession

/// Lightweight on-device Apple Neural Engine (`MLComputeUnits.cpuAndNeuralEngine`) context scorer.
/// Never called synchronously inside per-keystroke composition; runs only at word boundaries or
/// asynchronous suggestion updates while respecting thermal state.
final class NeuralContextScorer: @unchecked Sendable {
    static let shared = NeuralContextScorer()

    private let lock = NSLock()
    private var loaded = false
    private var languageModel: NLModel?
    private var domainModel: NLModel?

    private init() {}

    var isANEReady: Bool {
        ensureLoaded()
        lock.lock()
        defer { lock.unlock() }
        return languageModel != nil && domainModel != nil
    }

    var statusSummary: String {
        if ProcessInfo.processInfo.thermalState == .critical {
            return "Tạm nghỉ bảo vệ nhiệt"
        }
        return isANEReady
            ? "Đang bật · Core ML (.cpuAndNeuralEngine)"
            : "Dự phòng thuần Swift"
    }

    /// Asynchronous background wrapper so `@MainActor` UI/IMK controllers never send `self` across actors.
    func evaluateLanguageHint(for context: String) async -> (hint: ContextLanguageHint, confidence: Double) {
        await Task.detached(priority: .utility) {
            NeuralContextScorer.shared.languageHint(for: context)
        }.value
    }

    /// Evaluates sentence context (`>= 10` characters) to disambiguate mixed English/Vietnamese typing.
    func languageHint(for context: String) -> (hint: ContextLanguageHint, confidence: Double) {
        guard ProcessInfo.processInfo.thermalState != .critical else {
            return (.automatic, 0)
        }
        let trimmed = String(context.suffix(180)).trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 10 else { return (.automatic, 0) }
        ensureLoaded()

        lock.lock()
        let model = languageModel
        lock.unlock()
        guard let model else { return (.automatic, 0) }

        let hypotheses = model.predictedLabelHypotheses(for: trimmed, maximumCount: 2)
        let enProb = hypotheses["en"] ?? 0
        let viProb = hypotheses["vi"] ?? 0
        if enProb >= 0.72, enProb > viProb {
            return (.english, enProb)
        }
        if viProb >= 0.72, viProb > enProb {
            return (.vietnamese, viProb)
        }
        return (.automatic, max(enProb, viProb))
    }

    /// Infers the active `VocabularyDomain` on ANE/CPU to sharpen multi-word & prefix completions.
    func inferredDomain(for context: String) -> VocabularyDomain? {
        guard ProcessInfo.processInfo.thermalState != .critical else {
            return SemanticRanker.inferDomain(from: context)
        }
        let trimmed = String(context.suffix(220)).trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 12 else {
            return SemanticRanker.inferDomain(from: context)
        }
        ensureLoaded()

        lock.lock()
        let model = domainModel
        lock.unlock()
        guard let model else {
            return SemanticRanker.inferDomain(from: context)
        }

        let hypotheses = model.predictedLabelHypotheses(for: trimmed, maximumCount: 2)
        if let best = hypotheses.max(by: { $0.value < $1.value }),
           best.value >= 0.52,
           let domain = VocabularyDomain(rawValue: best.key),
           domain != .general {
            return domain
        }
        return SemanticRanker.inferDomain(from: context)
    }

    private func ensureLoaded() {
        lock.lock()
        if loaded {
            lock.unlock()
            return
        }
        loaded = true
        lock.unlock()

        let cfg = MLModelConfiguration()
        cfg.computeUnits = .cpuAndNeuralEngine

        let loadedLang = Self.loadNLModel(named: "VitekLanguageContext", configuration: cfg)
        let loadedDomain = Self.loadNLModel(named: "VitekDomainClassifier", configuration: cfg)

        lock.lock()
        languageModel = loadedLang
        domainModel = loadedDomain
        lock.unlock()
    }

    private static func loadNLModel(named name: String, configuration: MLModelConfiguration) -> NLModel? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "mlmodelc"),
              let mlModel = try? MLModel(contentsOf: url, configuration: configuration) else {
            return nil
        }
        return try? NLModel(mlModel: mlModel)
    }
}
