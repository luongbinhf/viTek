import Testing
import VitekSession

@Suite struct SuggestionRequestTests {
    private final class Client {}

    @Test func lateResponseCannotReplaceNewerRequest() {
        let client = Client()
        let snapshot = SuggestionRequest.Snapshot(client: ObjectIdentifier(client), caret: 3, prefix: "ngu", context: "ngu")
        var requests = SuggestionRequest()
        let old = requests.begin(snapshot)
        let latest = requests.begin(snapshot)
        #expect(!requests.isCurrent(old, snapshot: snapshot))
        #expect(requests.isCurrent(latest, snapshot: snapshot))
    }

    @Test func focusAndCaretChangesRejectPendingAndDisplayedResults() {
        let first = Client(), second = Client()
        let initial = SuggestionRequest.Snapshot(client: ObjectIdentifier(first), caret: 3, prefix: "ngu", context: "ngu")
        var requests = SuggestionRequest()
        let ticket = requests.begin(initial)
        for changed in [
            SuggestionRequest.Snapshot(client: ObjectIdentifier(second), caret: 3, prefix: "ngu", context: "ngu"),
            SuggestionRequest.Snapshot(client: ObjectIdentifier(first), caret: 2, prefix: "ngu", context: "ngu"),
            SuggestionRequest.Snapshot(client: ObjectIdentifier(first), caret: 3, prefix: "ngu", context: "abc"),
            SuggestionRequest.Snapshot(client: ObjectIdentifier(first), caret: 3, prefix: "ngư", context: "ngu"),
            SuggestionRequest.Snapshot(client: ObjectIdentifier(first), caret: 3, prefix: "ngu", context: nil),
        ] { #expect(!requests.isCurrent(ticket, snapshot: changed)) }
        requests.invalidate()
        #expect(!requests.isCurrent(ticket, snapshot: initial))
    }

    @Test func unreadableHostStillRequiresSameRevisionAndClient() {
        let client = Client()
        let snapshot = SuggestionRequest.Snapshot(client: ObjectIdentifier(client), caret: 3, prefix: "ngu", context: nil)
        var requests = SuggestionRequest()
        let ticket = requests.begin(snapshot)
        #expect(requests.isCurrent(ticket, snapshot: snapshot))
        requests.invalidate()
        #expect(!requests.isCurrent(ticket, snapshot: snapshot))
    }

    @Test func returningToSameCaretCannotReviveCancelledResults() {
        let client = Client()
        let initial = SuggestionRequest.Snapshot(client: ObjectIdentifier(client), caret: 9, prefix: "", context: "cơ sở dữ ")
        var requests = SuggestionRequest()
        let pending = requests.begin(initial)
        requests.invalidate() // Left: host invalidates before navigation is passed through.
        requests.invalidate() // Right: caret and readable context are identical again.
        #expect(!requests.isCurrent(pending, snapshot: initial))
        let fresh = requests.begin(initial)
        #expect(requests.isCurrent(fresh, snapshot: initial))
        #expect(!requests.isCurrent(pending, snapshot: initial))
    }
}
