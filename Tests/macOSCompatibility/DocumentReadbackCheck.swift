import AppKit
import VitekSession

@main struct DocumentReadbackCheck {
    @MainActor static func main() {
        var failures = 0
        func check(_ condition: Bool, _ label: String) {
            if condition { print("PASS \(label)") }
            else { failures += 1; print("FAIL \(label)") }
        }
        let range = DocumentRange(5, 3)!
        for length in [NSNotFound, -1, 7] {
            var queries = 0
            let text = IMKDocumentClient.verifiedText(in: range, documentLength: length, selection: nil) { _ in
                queries += 1
                return "nam" // Selected-text fallback can have exactly the requested length.
            }
            check(text == nil && queries == 0, "reject unavailable/out-of-bounds document length \(length)")
        }
        check(IMKDocumentClient.verifiedText(in: range, documentLength: 8, selection: nil) { _ in "nam" } == "nam", "verified document substring")
        check(IMKDocumentClient.verifiedText(in: range, documentLength: 8, selection: nil) { _ in "na" } == nil, "reject truncated substring")
        let insertion = DocumentRange(8, 0)!
        check(IMKDocumentClient.verifiedText(in: insertion, documentLength: NSNotFound, selection: insertion) { _ in "x" } == nil, "reject selected-text fallback for empty range")
        check(IMKDocumentClient.verifiedText(in: insertion, documentLength: 8, selection: insertion) { _ in nil } == "", "verified empty insertion point")
        guard failures == 0 else { exit(1) }
    }
}
