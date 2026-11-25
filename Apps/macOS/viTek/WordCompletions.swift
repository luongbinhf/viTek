import AppKit
import VitekSession

/// Serializes access to the system completion service. It may wait on the spell server for
/// tens of milliseconds. Only strings cross from the input controller to this worker.
actor WordCompletions {
    static let shared = WordCompletions()

    func words(context: String, prefix: String, personal: PersonalFrequency? = nil) -> [WordCandidate] {
        guard !Task.isCancelled,
              let partial = Terminology.prefixLength(context: context, prefix: prefix) else { return [] }
        let local = WordPrediction.suggest(context: context, prefix: prefix, personal: personal)
        guard WordPrediction.policy(context: context, prefix: prefix) == .prose,
              prefix.count >= 2, local.first?.source != .phrase, local.count < 5 else { return local }
        let range = NSRange(location: context.utf16.count - partial, length: partial)
        let raw = NSSpellChecker.shared.completions(forPartialWordRange: range, in: context,
                                                    language: "vi", inSpellDocumentWithTag: 0) ?? []
        guard !Task.isCancelled else { return [] }
        return WordPrediction.suggest(context: context, prefix: prefix, personal: personal, systemCandidates: raw)
    }
}
