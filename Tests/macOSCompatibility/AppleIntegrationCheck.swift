import Foundation
import FoundationModels
import AppIntents

/// Compile with shared WritingLink, WritingSuggestion and ContinueWritingIntent.
/// Uses only fixed QA text; never reads the user's text.
@main struct AppleIntegrationCheck {
    @MainActor static func main() async throws {
        for raw in ["vitek://writing", "vitek://writing/"] {
            precondition(WritingLink.matches(URL(string: raw)!))
        }
        for raw in ["https://writing", "vitek://other", "vitek://writing/other", "vitek://writing?draft=secret", "vitek://writing#secret", "vitek://user@writing", "vitek://writing:80"] {
            precondition(!WritingLink.matches(URL(string: raw)!))
        }
        precondition(WritingSuggestion.readiness(for: .available, supportsVietnamese: true).canGenerate)
        precondition(!WritingSuggestion.readiness(for: .available, supportsVietnamese: false).canGenerate)
        for reason: SystemLanguageModel.Availability.UnavailableReason in [.appleIntelligenceNotEnabled, .deviceNotEligible, .modelNotReady] {
            let state = WritingSuggestion.readiness(for: .unavailable(reason), supportsVietnamese: true)
            precondition(!state.canGenerate && !state.message.isEmpty)
        }
        let trimmed = try WritingSuggestion.validatedDraft("  Xin chào \n")
        precondition(trimmed == "Xin chào")
        _ = try WritingSuggestion.validatedDraft(String(repeating: "a", count: 2400))
        _ = try WritingSuggestion.validatedDraft(String(repeating: "ệ", count: 800))
        for draft in [" \n", String(repeating: "a", count: 2401), String(repeating: "ệ", count: 801), "a" + String(repeating: "\u{301}", count: 1200)] {
            do { _ = try WritingSuggestion.validatedDraft(draft); fatalError("Invalid input accepted") }
            catch is WritingSuggestion.Failure { }
        }
        let cancelled = Task { @MainActor in try await WritingSuggestion.generate(from: "Hôm nay tôi") }
        cancelled.cancel()
        do { _ = try await cancelled.value; fatalError("Cancelled generation returned text") }
        catch is CancellationError { }
        print("APPLE INTEGRATION CHECK PASSED: URL boundary, availability, UTF-8 limits, cancellation")
        let readiness = WritingSuggestion.readiness()
        print("REAL MODEL: \(readiness.message)")
        if CommandLine.arguments.contains("--generate"), readiness.canGenerate {
            var snapshots = 0
            let text = try await WritingSuggestion.generate(from: "Sáng nay tôi đi dạo trong công viên.") { _ in snapshots += 1 }
            precondition(!text.isEmpty && snapshots > 0)
            print("REAL GENERATION PASSED snapshots=\(snapshots) characters=\(text.count)")
            let intent = ContinueWritingIntent()
            intent.draft = "Sáng nay tôi đi dạo trong công viên."
            let result = try await intent.perform()
            precondition(result.value?.isEmpty == false)
            print("CONTINUE WRITING INTENT PASSED")
        }
    }
}
