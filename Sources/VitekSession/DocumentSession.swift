/// A validated document-relative UTF-16 range. Unknown host positions are represented by nil.
public struct DocumentRange: Equatable, Sendable {
    public let location: Int
    public let length: Int
    public var end: Int { location + length }

    public init?(_ location: Int, _ length: Int) {
        guard location >= 0, length >= 0, location < Int.max, length < Int.max - location else { return nil }
        self.location = location
        self.length = length
    }
}

/// The two adapters are IMK and the real Cocoa text client in the regression tests.
/// nil replacement means the host's current selection/marked text, never a guessed offset.
@MainActor public protocol DocumentClient {
    var documentID: ObjectIdentifier { get }
    var selection: DocumentRange? { get }
    var markedRange: DocumentRange? { get }
    func text(in range: DocumentRange) -> String?
    func insert(_ text: String, replacing range: DocumentRange?)
    func mark(_ text: String, replacing range: DocumentRange?)
}

/// Owns the editing transaction, including caret movement, focus loss and stale host state.
/// Readable hosts receive committed edits on every key, so search does not wait for composition.
/// Unreadable hosts keep native composition ownership instead of guessing replacement ranges.
public struct DocumentSession: Sendable, CustomDebugStringConvertible {
    public var session: InputSession
    private enum Transport: Sendable { case committed, marked }
    private var transport: Transport?
    private var ownedRange: DocumentRange?
    private var expectedSelection: DocumentRange?
    private var shown = ""
    private var literalUntilBoundary = false
    private var selectionReplacement: DocumentRange?
    /// Length of a host-injected inline autocomplete selection right after our owned word
    /// (Chrome/Safari Omnibox, Spotlight). Cleared on acknowledgement or discard.
    private var inlineAutocompleteLength = 0
    private var owner: ObjectIdentifier?
    private struct Revision: Sendable {
        var range: DocumentRange
        var selection: DocumentRange
        var text: String
    }
    private var awaiting: [Revision] = []
    private var awaitingSince: ContinuousClock.Instant?
    private struct NativeRevision: Sendable {
        var range: DocumentRange?
        var selection: DocumentRange?
        var text: String?
    }
    private var nativeAwaiting: [NativeRevision] = []
    private var previousNativeObservation: NativeRevision?
    private var provisionalNativeStart: Int?
    private var needsFreshAnchor = false
    private var nativeAnchorUnconfirmed = false
    private var nativeMarkAwaitingCaret = false
    private var allowsLateFocusCommit = false
    private var finishedRevision: Revision?

    public init(session: InputSession = InputSession()) { self.session = session }

    /// Positions and lengths only; opt-in host diagnostics must never include typed text.
    public var debugDescription: String {
        let mode: String
        switch transport {
        case .committed: mode = "committed"
        case .marked: mode = "marked"
        case nil: mode = literalUntilBoundary ? "literal" : "idle"
        }
        let range = ownedRange.map { "\($0.location):\($0.length)" } ?? "unknown"
        let caret = expectedSelection.map { "\($0.location):\($0.length)" } ?? "unknown"
        return "mode=\(mode) owned=\(range) expected=\(caret) inFlight=\(awaiting.count)"
    }

    /// Reconcile before suggestions, resume, or any editing decision. Never write stale text back.
    @MainActor @discardableResult public mutating func reconcile(with client: any DocumentClient) -> Bool {
        if let owner, owner != client.documentID {
            resetForFocusChange()
            self.owner = client.documentID
            return false
        }
        owner = client.documentID
        guard let transport else { return true }
        switch transport {
        case .committed:
            guard let ownedRange else {
                discard()
                return false
            }
            var selection = client.selection
            var current = client.text(in: ownedRange)
            if !awaiting.isEmpty, selection != expectedSelection || current != shown {
                // The renderer may acknowledge between the two synchronous queries.
                selection = client.selection
                current = client.text(in: ownedRange)
            }
            if current == shown, selection == expectedSelection {
                inlineAutocompleteLength = 0
                acknowledge(range: ownedRange, selection: selection, text: shown)
                return true
            }
            // Browser omnibox / Spotlight inline autocomplete selects a suggested suffix
            // immediately after our verified owned word (`vie[tnam.com]`). Keep ownership so
            // the next key replaces both the word and the stale autocomplete cleanly.
            if current == shown, let selection, let expectedSelection,
               expectedSelection.length == 0,
               selection.location == expectedSelection.location,
               selection.length > 0,
               DocumentRange(ownedRange.location, ownedRange.length + selection.length) != nil {
                inlineAutocompleteLength = selection.length
                return true
            }
            // Chromium sends explicit replacements to its renderer but keeps its old synchronous
            // query cache until a later frame. Only a complete previous transaction is admissible
            // while awaiting acknowledgement; a real new selection/content invalidates ownership.
            if let awaitingSince,
               ContinuousClock.now - awaitingSince < .milliseconds(500),
               awaiting.contains(where: {
                   (current != shown || $0.range.length > ownedRange.length)
                       && ($0.selection == selection || (current == nil && selection == expectedSelection))
                       && client.text(in: $0.range) == $0.text
               }) {
                return true
            }
            guard selection == expectedSelection else {
                discard()
                literalUntilBoundary = true
                return false
            }
            if current != shown {
                // Losing readback cannot authorize overwriting previously committed text. Keep
                // the visible prefix and pass this token's remaining keys through verbatim.
                let unavailable = current == nil
                let unacknowledged = !awaiting.isEmpty
                discard()
                literalUntilBoundary = unavailable || unacknowledged
                return false
            }
        case .marked:
            let liveMark = client.markedRange
            let selection = client.selection
            let current = liveMark.flatMap { client.text(in: $0) }
            // Electron can alternate document and composition-relative caret coordinates.
            // A same-length modifier (d -> đ) cannot establish an anchor by length growth.
            // While that native write is pending, retain a relative caret only when the
            // mark text is verified, or both parts of this mixed frame were observed before.
            // This authorizes only another host-owned mark, never an absolute replacement.
            if nativeAnchorUnconfirmed, nativeMarkAwaitingCaret,
               let awaitingSince, ContinuousClock.now - awaitingSince < .milliseconds(500),
               let liveMark, liveMark.location > 0, liveMark.length == shown.utf16.count,
               let selection, selection.length == 0, selection.location == liveMark.length,
               current == shown || (current == nil
                   && nativeAwaiting.contains(where: { $0.selection == selection })
                   && nativeAwaiting.contains(where: { $0.range == liveMark })) {
                // Retain the observed coordinate system across a typing pause; repeatedly
                // accepting it only until the cache deadline would drop the word afterwards.
                // The anchor remains provisional and transport stays native/host-owned.
                provisionalNativeStart = 0
                ownedRange = DocumentRange(0, shown.utf16.count)
                expectedSelection = selection
                return true
            }
            // After reset, a stale offset can sit *inside* the new word (old caret 1,
            // actual caret 0). Two native acknowledgements that advance both mark length
            // and caret by the same amount establish a relative anchor even in that case.
            // This is not a timeout extension and never permits an absolute replacement.
            if nativeAnchorUnconfirmed, nativeMarkAwaitingCaret, current == nil,
               let liveMark, liveMark.length == shown.utf16.count,
               let selection, selection.length == 0,
               let previous = previousNativeObservation,
               let previousMark = previous.range, previousMark.length > 0,
               previousMark.location == liveMark.location, liveMark.length > previousMark.length,
               let previousSelection = previous.selection, previousSelection.length == 0,
               selection.location - previousSelection.location == liveMark.length - previousMark.length,
               let adjacent = DocumentRange(selection.location - shown.utf16.count, shown.utf16.count) {
                provisionalNativeStart = adjacent.location
            }
            // The first native mark may replace a selection that only reaches the
            // synchronous cache afterwards. While that first write is unacknowledged,
            // retain its host-owned mark instead of deleting at the obsolete selection.
            if nativeAnchorUnconfirmed, nativeMarkAwaitingCaret, current == nil,
               let awaitingSince, ContinuousClock.now - awaitingSince < .milliseconds(500),
               let liveMark, liveMark == ownedRange, liveMark.length == shown.utf16.count,
               let selection, selection.length > 0,
               nativeAwaiting.count == 1, nativeAwaiting[0].range == nil {
                return true
            }
            // Native mark and caret caches can acknowledge separate renderer frames.
            // With an unconfirmed offset, the previous native mark's end can arrive
            // after the caret has briefly switched to document coordinates. Retain
            // only this known frame; do not turn its offset into an absolute write.
            if nativeAnchorUnconfirmed, nativeMarkAwaitingCaret, current == nil,
               let awaitingSince, ContinuousClock.now - awaitingSince < .milliseconds(500),
               let liveMark, liveMark.length == shown.utf16.count,
               let selection, selection.length == 0,
               nativeAwaiting.contains(where: {
                   $0.range?.location == liveMark.location && $0.range?.end == selection.location
               }) {
                return true
            }
            // Native mark and caret caches can acknowledge separate renderer frames.
            // While a native write is unconfirmed, a new mark with the exact old
            // caret is a partial acknowledgement, not evidence of a user caret move.
            // Keep edits host-owned; this cannot authorize an absolute replacement.
            if nativeMarkAwaitingCaret,
               let awaitingSince, ContinuousClock.now - awaitingSince < .milliseconds(500),
               let liveMark, liveMark == ownedRange, liveMark.length == shown.utf16.count,
               current == nil || current == shown,
               let selection, selection.length == 0, selection != expectedSelection,
               nativeAwaiting.contains(where: { $0.selection == selection && $0.range != liveMark }) {
                return true
            }
            // Chromium can deliver the collapsed caret from a selection deletion
            // after acknowledging several newer marked characters. Only the initial
            // selected range at this native mark's origin explains that delayed caret.
            if nativeAnchorUnconfirmed, nativeMarkAwaitingCaret, current == nil,
               let awaitingSince, ContinuousClock.now - awaitingSince < .milliseconds(500),
               let liveMark, liveMark == ownedRange, liveMark.length == shown.utf16.count,
               selection == DocumentRange(liveMark.location, 0),
               let initial = nativeAwaiting.first, initial.range == nil,
               let replaced = initial.selection, replaced.length > 0, replaced.location == liveMark.location {
                return true
            }
            // Known pending frames above take priority over a provisional anchor: the
            // native caret can lag the mark by one character, then briefly show the
            // pre-mark caret. Do not reinterpret that acknowledgement as a caret move.
            if nativeAnchorUnconfirmed, current == nil, let start = provisionalNativeStart,
               let liveMark, liveMark.length == shown.utf16.count,
               let anchored = DocumentRange(start, shown.utf16.count),
               let selection, selection == DocumentRange(anchored.end, 0) {
                ownedRange = anchored
                expectedSelection = selection
            }
            // After focus/reset, Chromium can update its caret while retaining the previous
            // field's absolute marked offset. Recover the first native anchor only from exact
            // text immediately before that caret. This never authorizes an absolute write:
            // the native mark stays host-owned until its own range becomes readable.
            if nativeAnchorUnconfirmed, let liveMark, liveMark.length == shown.utf16.count,
               let selection, selection.length == 0,
               let adjacent = DocumentRange(selection.location - shown.utf16.count, shown.utf16.count),
               client.text(in: adjacent) == shown {
                ownedRange = adjacent
                expectedSelection = selection
                nativeAnchorUnconfirmed = false
            }
            // Unreadable Chromium fields may acknowledge a new mark length and caret while
            // retaining the old field's marked offset. Only a pending native revision can
            // establish this relative anchor; all writes still target the host-owned mark.
            if nativeAnchorUnconfirmed, current == nil,
               let liveMark, liveMark.length == shown.utf16.count,
               let selection, selection.length == 0, liveMark.end != selection.location,
               let ownedRange, selection.location < ownedRange.location || selection.location > ownedRange.end,
               nativeAwaiting.contains(where: { $0.range?.length != liveMark.length && $0.selection != selection }),
               let adjacent = DocumentRange(selection.location - shown.utf16.count, shown.utf16.count) {
                self.ownedRange = adjacent
                expectedSelection = selection
                // A relative caret can itself still be a cached frame. Without text
                // readback this anchor remains provisional for the next native update.
            }
            // The renderer can correct the initial anchor after the first native mark.
            // A host may switch from composition-relative to document-relative caret
            // coordinates. A newly acknowledged native mark can establish its own end;
            // absolute replacements still require text readback in apply().
            if let liveMark, liveMark != ownedRange,
               liveMark.length == shown.utf16.count,
               current == shown || (current == nil && nativeAwaiting.contains(where: { $0.range?.length != liveMark.length })),
               selection == DocumentRange(liveMark.end, 0) {
                ownedRange = liveMark
                expectedSelection = DocumentRange(liveMark.end, 0)
            }
            if liveMark != ownedRange || selection != expectedSelection || (current != nil && current != shown) {
                // Native fallback also crosses the process boundary. A cached pre-mark frame
                // is admissible only while it exactly matches a frame this transaction saw.
                // This keeps unreadable hosts working without inventing an absolute edit range.
                if let awaitingSince, ContinuousClock.now - awaitingSince < .milliseconds(500),
                   nativeAwaiting.contains(where: {
                       $0.range == liveMark && $0.selection == selection && (current == nil || $0.text == current)
                   }) { return true }
            }
            // Some Electron fields expose an obsolete absolute mark offset while the native
            // composition's length and caret still advance correctly. With no readback, keep
            // using the host-owned mark (nil replacement), never that unverified absolute range.
            if let liveMark, current == nil || current == shown, liveMark.length == shown.utf16.count,
               let expectedSelection, selection == expectedSelection {
                nativeMarkAwaitingCaret = false
                return true
            }
            if let expectedSelection, let selection, selection != expectedSelection {
                // A programmatic caret move can bypass mouse callbacks. Release the old marking
                // at an insertion point without inserting the buffered word a second time.
                if selection.length == 0 { client.insert("", replacing: selection) }
                discard()
                if selection.length > 0 { selectionReplacement = selection }
                return false
            }
            if let ownedRange, liveMark != ownedRange {
                discard()
                return false
            }
            // Native marked text remains host-owned even when Chromium's substring cache
            // disagrees. The mark and caret checks above establish ownership; keep updating
            // it through nil replacement ranges until they move or the host ends the mark.
            // Readback is still required before promoting to absolute committed replacements.
            // In particular, insertText("") here can delete the first marked character.

        }
        return true
    }

    @MainActor public mutating func handle(_ event: HostEvent, client: any DocumentClient,
                                          prefersMarkedText: Bool = false) -> SessionOutput {
        reconcile(with: client)
        if case .boundary = event {
            interrupt(client: client)
            // A shortcut/navigation key can focus a different field while IMK still reports
            // the previous field's readable caret. Let the host anchor the first edit there;
            // do not turn that cached position into an explicit replacement for the next key.
            needsFreshAnchor = true
            allowsLateFocusCommit = true
            return SessionOutput(commands: [], passThrough: true)
        }
        if literalUntilBoundary {
            if case .backspace = event {
                // Let the host delete at its actual selection. The next word starts at
                // the host-owned caret even if synchronous readback still predates deletion.
                discard()
                needsFreshAnchor = true
            } else if case .character(let key) = event, !key.isLetter && !key.isNumber {
                literalUntilBoundary = false
            }
            return SessionOutput(commands: [], passThrough: true)
        }
        if case .backspace = event, let selectionReplacement {
            client.insert("", replacing: selectionReplacement)
            discard()
            return SessionOutput(commands: [], passThrough: false)
        }
        let output = session.handle(event)
        apply(output.commands, client: client, prefersMarkedText: prefersMarkedText)
        if case .backspace = event, output.passThrough {
            finishedRevision = nil
            needsFreshAnchor = true
        }
        return output
    }

    /// A reused Chromium client may deliver the old field's commit after the first key
    /// following Tab/Cmd+F. Its pre-mark frame cannot revoke our new native transaction.
    /// Navigation/deactivation still use interrupt, and ordinary commits are unchanged.
    @MainActor public mutating func commitComposition(client: any DocumentClient) {
        let liveMark = client.markedRange
        let selection = client.selection
        let provisionalStart = selection.map {
            liveMark == nil ? $0.location : max(0, $0.location - shown.utf16.count)
        } ?? ownedRange?.location
        if allowsLateFocusCommit, nativeAnchorUnconfirmed, transport == .marked,
           owner == client.documentID, !shown.isEmpty,
           let awaitingSince, ContinuousClock.now - awaitingSince < .milliseconds(500),
           selection == nil || selection?.length == 0,
           (liveMark == nil && selection != nil && selection != expectedSelection)
               || (liveMark?.length == shown.utf16.count && liveMark?.end != selection?.location),
           let provisionalStart, let anchored = DocumentRange(provisionalStart, shown.utf16.count) {
            ownedRange = anchored
            expectedSelection = DocumentRange(anchored.end, 0)
            nativeAwaiting.append(NativeRevision(range: liveMark, selection: selection, text: nil))
            // After the old field commits, Chromium may briefly expose the new field's
            // pre-mark frame even though its first native character is already visible.
            if liveMark != nil {
                nativeAwaiting.append(NativeRevision(range: nil, selection: DocumentRange(anchored.location, 0), text: nil))
                // During the focus handoff, the empty new field's caret can reset
                // before Chromium invalidates the old field's marked offset.
                nativeAwaiting.append(NativeRevision(range: liveMark, selection: DocumentRange(0, 0), text: nil))
            }
            allowsLateFocusCommit = false
            return
        }
        interrupt(client: client)
    }

    /// Called before a pointer/navigation action, on IMK commit, and on deactivation. Preserve
    /// the spelling already visible; focus loss must not run dictionary restoration or shortcuts.
    @MainActor public mutating func interrupt(client: any DocumentClient) {
        // A late deactivate/commit for the previous client must not clear the new client's word.
        guard owner == nil || owner == client.documentID else { return }
        guard reconcile(with: client) else { return }
        if transport == .marked, !shown.isEmpty { client.insert(shown, replacing: nil) }
        discard()
    }

    public mutating func discard() {
        session.discard()
        transport = nil
        ownedRange = nil
        expectedSelection = nil
        shown = ""
        literalUntilBoundary = false
        selectionReplacement = nil
        inlineAutocompleteLength = 0
        owner = nil
        awaiting = []
        awaitingSince = nil
        nativeAwaiting = []
        previousNativeObservation = nil
        provisionalNativeStart = nil
        needsFreshAnchor = false
        nativeAnchorUnconfirmed = false
        nativeMarkAwaitingCaret = false
        allowsLateFocusCommit = false
        finishedRevision = nil
    }

    /// A new focus session may still expose the previous field's synchronous query cache.
    public mutating func resetForFocusChange() {
        discard()
        needsFreshAnchor = true
    }

    private mutating func acknowledge(range: DocumentRange, selection: DocumentRange?, text: String) {
        // Delete/retype can return to an earlier visible value (ABA). That value alone is not a
        // revision acknowledgement: an intermediate renderer frame may still arrive afterwards.
        guard !awaiting.contains(where: { $0.range == range && $0.selection == selection && $0.text == text }) else { return }
        awaiting = []
        awaitingSince = nil
    }

    /// Resume only text the host can verify, using committed replacement rather than marking it.
    @MainActor public mutating func resume(_ word: String, range: DocumentRange, client: any DocumentClient) -> Bool {
        guard transport == nil, !literalUntilBoundary, client.selection == DocumentRange(range.end, 0),
              client.text(in: range) == word, session.resume(word) else { return false }
        transport = .committed
        owner = client.documentID
        ownedRange = range
        expectedSelection = client.selection
        shown = word
        return true
    }

    /// Explicitly accepted completion. It must still belong to this document transaction.
    @MainActor public mutating func accept(_ text: String, client: any DocumentClient) -> Bool {
        guard reconcile(with: client), !literalUntilBoundary else { return false }
        apply([.insert(text)], client: client, prefersMarkedText: false)
        session.discard()
        return true
    }

    @MainActor private mutating func apply(_ commands: [HostCommand], client: any DocumentClient,
                                           prefersMarkedText: Bool) {
        for command in commands {
            let text: String
            let finishes: Bool
            switch command {
            case .mark(let value): text = value; finishes = value.isEmpty
            case .insert(let value): text = value; finishes = true
            }
            if transport == nil {
                if needsFreshAnchor, let finished = finishedRevision,
                   let selection = client.selection, selection.length == 0,
                   selection.location > finished.range.end,
                   client.text(in: finished.range) == finished.text,
                   let gap = DocumentRange(finished.range.end, selection.location - finished.range.end),
                   let separator = client.text(in: gap),
                   separator.allSatisfy({ !$0.isLetter && !$0.isNumber }) {
                    needsFreshAnchor = false
                }
                finishedRevision = nil
                if !prefersMarkedText, !needsFreshAnchor, let selection = client.selection, client.markedRange == nil,
                   let original = client.text(in: selection), original.utf16.count == selection.length {
                    transport = .committed
                    ownedRange = selection
                    expectedSelection = selection
                    shown = original
                } else {
                    transport = .marked
                    nativeAnchorUnconfirmed = true
                }
                needsFreshAnchor = false
            }
            // After an unacknowledged word boundary, let the host anchor the next word natively.
            // Once a later key sees that native mark at its confirmed location, commit it through
            // the ordinary current-composition path. Never mark and commit within the same key.
            var commitsNativeMark = false
            if transport == .marked, !prefersMarkedText, !shown.isEmpty, !text.isEmpty,
               let liveMark = client.markedRange, client.text(in: liveMark) == shown,
               client.selection == DocumentRange(liveMark.end, 0) {
                transport = .committed
                ownedRange = liveMark
                expectedSelection = client.selection
                nativeAwaiting = []
                previousNativeObservation = nil
                provisionalNativeStart = nil
                awaitingSince = nil
                commitsNativeMark = true
            }
            switch transport {
            case .committed:
                guard let range = ownedRange, let updated = DocumentRange(range.location, text.utf16.count) else {
                    discard()
                    return
                }
                let replaceRange = DocumentRange(range.location, range.length + inlineAutocompleteLength) ?? range
                inlineAutocompleteLength = 0
                if shown != text || commitsNativeMark {
                    if let expectedSelection {
                        awaiting.append(Revision(range: range, selection: expectedSelection, text: shown))
                        if awaiting.count > 32 { awaiting.removeFirst() }
                        if awaitingSince == nil { awaitingSince = ContinuousClock.now }
                    }
                    // At the user's current selection, use the host's normal insertion path.
                    // Chromium can retain the replacement as a selection for an explicit range,
                    // making the next key overwrite the first. Explicit ranges are only needed
                    // to revise the verified word behind the caret.
                    let currentSelection = replaceRange == client.selection && client.markedRange == nil
                    client.insert(text, replacing: commitsNativeMark || currentSelection ? nil : replaceRange)
                }
                ownedRange = updated
                expectedSelection = DocumentRange(updated.end, 0)
                if client.text(in: updated) == text, client.selection == expectedSelection {
                    acknowledge(range: updated, selection: expectedSelection, text: text)
                }
            case .marked:
                // IMK writes are delivered to another process. Queries made immediately after
                // setMarkedText may still describe the previous frame, so derive the next range
                // from the transaction we just sent, not from that stale acknowledgement.
                let start = ownedRange?.location ?? selectionReplacement?.location
                    ?? client.selection?.location ?? client.markedRange?.location
                if !finishes {
                    nativeMarkAwaitingCaret = true
                    let previousMark = client.markedRange
                    let observation = NativeRevision(range: previousMark, selection: client.selection,
                                                     text: previousMark.flatMap { client.text(in: $0) })
                    previousNativeObservation = observation
                    nativeAwaiting.append(observation)
                    if let ownedRange {
                        nativeAwaiting.append(NativeRevision(range: ownedRange, selection: expectedSelection, text: shown))
                    }
                    if nativeAwaiting.count > 32 { nativeAwaiting.removeFirst(nativeAwaiting.count - 32) }
                    if awaitingSince == nil { awaitingSince = ContinuousClock.now }
                }
                // An empty native commit can be ignored by Chromium. A Backspace
                // that empties composition must update the marked text to empty.
                if case .insert = command { client.insert(text, replacing: selectionReplacement) }
                else { client.mark(text, replacing: selectionReplacement) }
                ownedRange = start.flatMap { DocumentRange($0, text.utf16.count) }
                expectedSelection = ownedRange.flatMap { DocumentRange($0.end, 0) }
            case nil: break
            }
            shown = text
            selectionReplacement = nil
            if finishes {
                // The empty mark cancels composition asynchronously. Chrome can report
                // a readable empty selection at the old offset before the deletion lands.
                finishedRevision = nil
                needsFreshAnchor = text.isEmpty || (transport == .committed && !awaiting.isEmpty)
                if needsFreshAnchor, !text.isEmpty, let range = ownedRange, let selection = expectedSelection {
                    finishedRevision = Revision(range: range, selection: selection, text: text)
                }
                transport = nil
                ownedRange = nil
                expectedSelection = nil
                shown = ""
                awaiting = []
                awaitingSince = nil
                nativeAwaiting = []
                previousNativeObservation = nil
                provisionalNativeStart = nil
                nativeAnchorUnconfirmed = false
                nativeMarkAwaitingCaret = false
                allowsLateFocusCommit = false
            }
        }
    }
}
