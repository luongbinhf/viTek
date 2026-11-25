#if canImport(AppKit)
import AppKit
import Testing
import VitekEngine
import VitekSession

@Suite @MainActor struct DocumentSessionTests {
    @Test func delayedSelectionDeletionCaretDoesNotEraseNewMark() {
        let host = DocumentHarness()
        host.view.string = "Gặp "
        host.view.setSelectedRange(NSRange(location: 0, length: 4))
        host.type("⌫")
        host.readable = false
        host.prefersMarkedText = true
        host.ignoresExplicitRangeWhileMarked = true
        host.keepsCachedQueriesAcrossKeys = true
        host.oldSelection = DocumentRange(0, 4)
        host.returningOldState = true
        host.type("v")
        host.returningOldState = false
        host.type("iee")
        host.oldMark = DocumentRange(0, 3)
        host.oldSelection = DocumentRange(0, 0)
        host.returningOldState = true
        host.type("t")
        host.returningOldState = false
        host.type("j ")
        #expect(host.view.string == "việt ")
    }

    @Test func emptyNativeMarkRequiresNewHostAnchorEvenWhenOldCaretLooksReadable() {
        let host = DocumentHarness()
        host.prefersMarkedText = true
        host.type("vieetj⌫⌫⌫⌫")
        host.prefersMarkedText = false
        host.keepsCachedQueriesAcrossKeys = true
        host.oldSelection = DocumentRange(0, 0)
        host.returningOldState = true
        host.type("G")
        #expect(host.view.hasMarkedText())
        host.returningOldState = false
        host.type("awpj ")
        #expect(host.view.string == "Gặp ")
    }

    @Test(arguments: [true, false])
    func retypeImmediatelyAfterDeletingUnverifiedText(_ restoresReadback: Bool) {
        let host = DocumentHarness()
        host.view.string = "trước  sau"
        host.view.setSelectedRange(NSRange(location: 6, length: 0))
        host.type("vie")
        host.readable = false
        host.type("⌫⌫⌫")
        host.readable = restoresReadback
        host.type("Gawpj")
        #expect(host.view.string == "trước Gặp sau")
        host.type(" ")
        #expect(!host.view.hasMarkedText())
    }

    @Test(arguments: [false, true])
    func confirmedRelativeNativeCoordinatesSurviveTypingPause(_ readable: Bool) {
        let host = DocumentHarness()
        host.view.string = "hợp "
        host.view.setSelectedRange(NSRange(location: 4, length: 0))
        host.readable = readable
        host.prefersMarkedText = true
        host.ignoresExplicitRangeWhileMarked = true
        host.relativeNativeCaret = true
        host.type("ddo")
        #expect(host.view.string == "hợp đo")
        Thread.sleep(forTimeInterval: 0.55)
        host.type("ongf ")
        #expect(host.view.string == "hợp đồng ")
    }

    @Test func repeatedModifierKeepsObservedRelativeCaretAfterProvisionalDocumentCaret() {
        // VS Code trace: after Space, d is anchored using caret 1; dd sees caret 4
        // with stale mark {1,1}; the next o sees that mark with relative caret 1.
        let host = DocumentHarness()
        host.view.string = "hợp "
        host.view.setSelectedRange(NSRange(location: 4, length: 0))
        host.readable = false
        host.prefersMarkedText = true
        host.ignoresExplicitRangeWhileMarked = true
        host.keepsCachedQueriesAcrossKeys = true
        host.delaysAcknowledgement = true
        host.returningOldState = true
        host.oldSelection = DocumentRange(1, 0)
        host.type("d")
        host.oldMark = DocumentRange(1, 1)
        host.oldSelection = DocumentRange(4, 0)
        host.type("d")
        host.oldMark = DocumentRange(1, 1)
        host.oldSelection = DocumentRange(1, 0)
        host.type("o")
        #expect(host.view.string == "hợp đo")
        host.returningOldState = false
        host.delaysAcknowledgement = false
        host.type("ongf lao ")
        #expect(host.view.string == "hợp đồng lao ")
    }

    @Test(arguments: [false, true], [false, true])
    func repeatedModifiersAfterSpaceSurviveRelativeNativeCaret(_ readable: Bool, _ firstMarkOnly: Bool) {
        let host = DocumentHarness()
        host.readable = readable
        host.prefersMarkedText = true
        host.ignoresExplicitRangeWhileMarked = true
        host.relativeNativeCaret = true
        host.relativeFirstMarkOnly = firstMarkOnly
        host.type(String(repeating: "howpj ddoongf lao ", count: 5))
        #expect(host.view.string == String(repeating: "hợp đồng lao ", count: 5))
    }

    @Test(arguments: [false, true], [false, true])
    func specialistPhraseWithRepeatedModifiersSurvivesLaggedCaret(_ readable: Bool, _ firstMarkOnly: Bool) {
        let host = DocumentHarness()
        host.readable = readable
        host.prefersMarkedText = true
        host.ignoresExplicitRangeWhileMarked = true
        host.nativeCaretLagsMark = true
        host.nativeCaretLagsFirstMarkOnly = firstMarkOnly
        host.type(String(repeating: "howpj ddoongf lao ", count: 5))
        #expect(host.view.string == String(repeating: "hợp đồng lao ", count: 5))
    }

    @Test(arguments: [false, true])
    func lateFocusCommitWithMatchingProvisionalCaretPreservesPrefix(_ missingCaret: Bool) {
        let host = DocumentHarness()
        _ = host.document.handle(.boundary, client: host)
        host.readable = false
        host.prefersMarkedText = true
        host.delaysAcknowledgement = true
        host.ignoresExplicitRangeWhileMarked = true
        host.keepsCachedQueriesAcrossKeys = true
        host.returningOldState = true
        host.oldSelection = DocumentRange(14, 0)
        host.type("v")
        for (key, length, caret) in [("i", 1, 11), ("e", 2, 12)] {
            host.oldMark = DocumentRange(14, length)
            host.oldSelection = DocumentRange(caret, 0)
            host.type(key)
        }
        host.oldMark = DocumentRange(14, 3)
        host.oldSelection = missingCaret ? nil : DocumentRange(13, 0)
        host.document.commitComposition(client: host)
        host.returningOldState = true
        host.oldMark = DocumentRange(14, 3)
        host.oldSelection = DocumentRange(0, 0)
        host.type("e")
        host.delaysAcknowledgement = false
        host.returningOldState = false
        host.type("tj ")
        #expect(host.view.string == "việt ")
    }
    @Test func staleNativeOffsetAndPreviousMarkEndPreserveTheWord() {
        let host = DocumentHarness()
        host.delaysAcknowledgement = true
        host.ignoresExplicitRangeWhileMarked = true
        host.view.string = "việt việt việt "
        host.view.setSelectedRange(NSRange(location: 15, length: 0))
        host.prefersMarkedText = true
        host.readable = false
        host.keepsCachedQueriesAcrossKeys = true
        host.returningOldState = true
        host.oldSelection = DocumentRange(11, 0)
        host.type("v")
        for (keys, length, caret) in [("i", 1, 11), ("e", 2, 12), ("65", 3, 13), ("t", 3, 15), (" ", 4, 14)] {
            host.oldMark = DocumentRange(11, length)
            host.oldSelection = DocumentRange(caret, 0)
            host.type(keys)
        }
        #expect(host.view.string == "việt việt việt việt ")
    }
    @Test(arguments: [false, true])
    func lateOldFieldCommitWithStaleMarkOffsetKeepsTheNewPrefix(_ returnsPreMarkFrame: Bool) {
        let host = DocumentHarness()
        _ = host.document.handle(.boundary, client: host)
        host.keepsCachedQueriesAcrossKeys = true
        host.ignoresExplicitRangeWhileMarked = true
        host.oldSelection = DocumentRange(5, 0)
        host.oldText = "việt "
        host.returningOldState = true
        host.type("v")
        host.oldSelection = DocumentRange(1, 0)
        host.oldMark = DocumentRange(5, 1)
        host.oldText = ""
        host.returningOldState = true
        host.document.commitComposition(client: host)
        host.returningOldState = returnsPreMarkFrame
        host.oldSelection = DocumentRange(0, 0)
        host.oldMark = nil
        host.type("i")
        host.returningOldState = false
        host.type("eetj ")
        #expect(host.view.string == "việt ")
    }
    @Test(arguments: [false, true])
    func nativeMarkAcknowledgedBeforeCaretPreservesFastWords(_ readable: Bool) {
        let host = DocumentHarness()
        host.readable = readable
        host.prefersMarkedText = true
        host.ignoresExplicitRangeWhileMarked = true
        host.nativeCaretLagsMark = true
        host.type(String(repeating: "vieetj vie65t ", count: 5))
        #expect(host.view.string == String(repeating: "việt việt ", count: 5))
    }

    @Test func acknowledgedNativeMarkDoesNotTreatCaretMoveAsPending() {
        let host = DocumentHarness()
        host.prefersMarkedText = true
        host.readable = false
        host.type("vieet")
        let acknowledged = host.document.reconcile(with: host)
        #expect(acknowledged)
        host.view.setSelectedRange(NSRange(location: 2, length: 0))
        let retained = host.document.reconcile(with: host)
        #expect(!retained)
    }

    @Test func unreadableAnchorCanCorrectAgainAfterPartiallyUpdatedCaret() {
        let host = DocumentHarness()
        host.view.string = "việt việt việt "
        host.view.setSelectedRange(NSRange(location: 15, length: 0))
        host.readable = false
        host.prefersMarkedText = true
        host.ignoresExplicitRangeWhileMarked = true
        host.keepsCachedQueriesAcrossKeys = true
        host.returningOldState = true
        host.oldSelection = DocumentRange(1, 0)
        host.markOffset = -14
        host.nativeCaretLagsMark = true
        host.nativeCaretLagsFirstMarkOnly = true
        host.type("vie65t ")
        #expect(host.view.string == "việt việt việt việt ")
    }

    @Test(arguments: [false, true])
    func backspaceAfterSelectionReplacementUsesHostWhenOldSelectionIsUnreadable(_ selectionArrivesLate: Bool) {
        let host = DocumentHarness()
        host.view.string = "việt nam "
        host.view.setSelectedRange(NSRange(location: 1, length: 2))
        host.prefersMarkedText = true
        host.readable = false
        if selectionArrivesLate {
            host.keepsCachedQueriesAcrossKeys = true
            host.returningOldState = true
            host.oldSelection = DocumentRange(0, 0)
        }
        host.type("a")
        #expect(host.view.string == "vat nam ")
        // Renderer has replaced the selection, but synchronous queries still expose it.
        host.keepsCachedQueriesAcrossKeys = true
        host.returningOldState = true
        host.oldSelection = DocumentRange(1, 2)
        host.oldMark = DocumentRange(selectionArrivesLate ? 0 : 1, 1)
        host.ignoresExplicitInsert = true
        host.ignoresEmptyNativeInsert = true
        host.forwardsBackspaceAsTextWhileMarked = true
        host.type("⌫")
        #expect(host.view.string == "vt nam ")
    }

    @Test(arguments: [false, true])
    func deletingLastNativeLetterDoesNotDependOnEmptyCommit(_ readable: Bool) {
        let host = DocumentHarness()
        host.prefersMarkedText = true
        host.readable = readable
        host.ignoresEmptyNativeInsert = true
        host.type("a⌫")
        #expect(host.view.string.isEmpty)
    }

    @Test(arguments: [false, true])
    func backspaceDeletesActualSelectionInsideNativeComposition(_ readable: Bool) {
        let host = DocumentHarness()
        host.prefersMarkedText = true
        host.readable = readable
        host.type("vieetj")
        host.view.setSelectedRange(NSRange(location: 1, length: 2))
        host.type("⌫")
        #expect(host.view.string == "vt")
    }
    @Test(arguments: [false, true])
    func nativeRelativeCaretAfterACommittedWordKeepsTheSecondWord(_ changesCoordinates: Bool) {
        let host = DocumentHarness()
        host.view.string = "việt "
        host.view.setSelectedRange(NSRange(location: 5, length: 0))
        host.prefersMarkedText = true
        host.ignoresExplicitRangeWhileMarked = true
        host.relativeNativeCaret = true
        host.relativeFirstMarkOnly = changesCoordinates
        host.type("v")
        host.document.reconcile(with: host)
        host.readable = !changesCoordinates
        host.type("ie65t ")
        #expect(host.view.string == "việt việt ")
    }

    @Test(arguments: [("n", "am", "nam"), ("v", "ieetj ", "việt ")])
    func lateOldFieldCommitCannotDiscardTheNewNativePrefix(_ sample: (String, String, String)) {
        let host = DocumentHarness()
        _ = host.document.handle(.boundary, client: host)
        host.keepsCachedQueriesAcrossKeys = true
        host.ignoresExplicitRangeWhileMarked = true
        host.oldSelection = DocumentRange(5, 0)
        host.oldText = "việt "
        host.returningOldState = true
        host.type(sample.0)
        // The old field's commit arrives with the new field's pre-mark query frame.
        host.oldSelection = DocumentRange(0, 0)
        host.oldMark = nil
        host.oldText = ""
        host.returningOldState = true
        host.document.commitComposition(client: host)
        host.returningOldState = false
        host.type(sample.1)
        #expect(host.view.string == sample.2)
    }

    @Test(arguments: [true, false])
    func freshNativeAnchorWithStaleMarkOffsetKeepsNativeOwnership(_ readable: Bool) {
        let host = DocumentHarness()
        host.document.resetForFocusChange()
        host.readable = readable
        host.keepsCachedQueriesAcrossKeys = true
        host.oldSelection = DocumentRange(7, 0)
        host.oldText = "vieetj "
        host.returningOldState = true
        host.markOffset = 7
        host.type("vieetj ")
        #expect(host.view.string == "việt ")
    }

    @Test(arguments: [false, true])
    func fieldSwitchWithCachedOldCaretDoesNotDropTheSecondLetter(_ reactivates: Bool) {
        let host = DocumentHarness()
        host.view.string = "cơ sở dữ "
        host.view.setSelectedRange(NSRange(location: 9, length: 0))
        _ = host.document.handle(.boundary, client: host) // Cmd+F
        if reactivates { host.document.resetForFocusChange() }
        host.oldSelection = DocumentRange(9, 0)
        host.oldText = host.view.string
        host.view.string = ""
        host.view.setSelectedRange(NSRange(location: 0, length: 0))
        host.keepsCachedQueriesAcrossKeys = true
        host.preservesCachedSnapshotAfterInsert = true
        host.delaysAcknowledgement = true
        host.returningOldState = true
        host.type("na")
        host.returningOldState = false // Find's renderer acknowledges its own document.
        host.preservesCachedSnapshotAfterInsert = false
        host.type("m")
        #expect(host.view.string == "nam")
    }
    @Test func partialNativeCaretFrameBeforeSpaceMustNotEraseTheWord() {
        let host = DocumentHarness()
        host.view.string = "việt "
        host.view.setSelectedRange(NSRange(location: 5, length: 0))
        host.document.resetForFocusChange()
        host.readable = false
        host.nativeCaretLagsMark = true
        host.ignoresExplicitRangeWhileMarked = true
        host.type("nam")
        #expect(host.view.string == "việt nam")
        host.laggedNativeCaret = DocumentRange(5, 0)
        host.type(" ")
        #expect(host.view.string == "việt nam ")
    }

    @Test func staleNativeOffsetInsideWordSurvivesAcknowledgementTimeout() {
        let host = DocumentHarness()
        host.document.resetForFocusChange()
        host.readable = false
        host.keepsCachedQueriesAcrossKeys = true
        host.oldSelection = DocumentRange(1, 0)
        host.returningOldState = true
        host.markOffset = 1
        host.type("viee")
        #expect(host.view.string == "viê")
        // The UI trace showed the fourth-to-fifth key crossing the 500ms cache limit.
        Thread.sleep(forTimeInterval: 0.55)
        host.type("tj ")
        #expect(host.view.string == "việt ")
    }

    @Test func freshUnreadableAnchorDoesNotMistakeAnInWordCaretMoveForAnAcknowledgement() {
        let host = DocumentHarness()
        host.view.string = "abcde "
        host.view.setSelectedRange(NSRange(location: 6, length: 0))
        host.document.resetForFocusChange()
        host.readable = false
        host.markOffset = 5
        host.type("vieetj")
        host.view.setSelectedRange(NSRange(location: 8, length: 0))
        host.type("⌫")
        #expect(host.view.string == "abcde vệt")
    }

    @Test func acknowledgedWordBoundaryDoesNotForceAnUnnecessaryNativeMark() {
        let host = DocumentHarness()
        host.keepsCachedQueriesAcrossKeys = true
        host.type("reset ")
        host.returningOldState = false
        host.type("s")
        #expect(host.view.string == "reset s")
        #expect(!host.view.hasMarkedText())
    }
    @Test func nativeReadbackMismatchWithIntactMarkMustKeepVietnameseComposition() {
        let host = DocumentHarness()
        host.prefersMarkedText = true
        host.ignoresExplicitRangeWhileMarked = true
        host.type("v")
        host.incorrectReadback = true
        host.type("ieetj ")
        #expect(host.view.string == "việt ")
    }

    @Test func chromiumReadbackMismatchMustKeepTheOwnedMarkWithoutDeletingItsPrefix() {
        let host = DocumentHarness()
        host.prefersMarkedText = true
        host.ignoresExplicitRangeWhileMarked = true
        host.type("n")
        host.incorrectReadback = true
        host.type("am")
        #expect(host.view.string == "nam")
    }

    @Test func incorrectNativeReadbackCannotMakeNextKeyReplaceTheVisiblePrefix() {
        let host = DocumentHarness()
        host.prefersMarkedText = true
        host.type("s")
        host.incorrectReadback = true
        host.type("erver ")
        #expect(host.view.string == "server ")
    }
    @Test(arguments: ["vieetj", "vie65t"])
    func unreadableNativeMarkWithStaleOffsetKeepsTheWholeWord(_ keys: String) {
        let host = DocumentHarness()
        host.readable = false
        host.markOffset = 5
        host.type(keys)
        #expect(host.view.string == "việt")
        host.type("⌫t ")
        #expect(host.view.string == "việt ")
    }

    @Test func staleNativeOffsetDoesNotAuthorizeEditingAfterCaretMovement() {
        let host = DocumentHarness()
        host.readable = false
        host.markOffset = 5
        host.type("vieetj")
        host.view.setSelectedRange(NSRange(location: 2, length: 0))
        host.type("⌫")
        #expect(host.view.string == "vệt")
    }
    @Test func deletingAtMovedCaretEditsTheDocumentRatherThanTheOldWord() {
        let host = DocumentHarness()
        host.type("vieetj")
        host.view.setSelectedRange(NSRange(location: 2, length: 0))
        host.type("⌫")
        #expect(host.view.string == "vệt")
    }

    @Test func replacingPartOfAWordPreservesItsNeighbours() {
        let host = DocumentHarness()
        host.type("vieetj")
        host.view.setSelectedRange(NSRange(location: 1, length: 2))
        host.type("a")
        #expect(host.view.string == "vat")
    }

    @Test func clientEndingCompositionCannotMakeALaterCommitDuplicateText() {
        let host = DocumentHarness()
        host.type("vieetj")
        host.view.unmarkText()
        host.flush()
        host.flush()
        #expect(host.view.string == "việt")
    }

    @Test func searchReceivesCommittedTextBeforeSpace() {
        let host = DocumentHarness()
        host.type("vieetj")
        #expect(host.view.string == "việt")
        #expect(!host.view.hasMarkedText())
    }

    @Test func omniboxInlineAutocompleteDoesNotBreakOrDuplicateVietnameseWord() {
        let host = DocumentHarness()
        host.type("vie")
        #expect(host.view.string == "vie")
        // Simulate Chrome/Safari Omnibox inserting a selected autocomplete suffix `tnam.com`.
        host.view.string = "vietnam.com"
        host.view.setSelectedRange(NSRange(location: 3, length: "tnam.com".utf16.count))
        host.type("etj")
        #expect(host.view.string == "việt")
        #expect(host.view.selectedRange() == NSRange(location: 4, length: 0))
    }

    @Test func leavingTheFieldPreservesTheSpellingAlreadyShown() {
        let host = DocumentHarness()
        host.type("vieet")
        host.flush()
        #expect(host.view.string == "viêt")
    }
    @Test func selectingAllDoesNotLeaveEachReplacementSelectedInTheHost() {
        let host = DocumentHarness()
        host.retainsExplicitSelection = true
        host.view.string = "old"
        host.view.setSelectedRange(NSRange(location: 0, length: 3))
        host.type("vieetj")
        #expect(host.view.string == "việt")
        #expect(host.view.selectedRange() == NSRange(location: 4, length: 0))
    }

    @Test func switchingClientsAndReceivingALateOldCommitCannotRewriteEitherField() {
        let first = DocumentHarness()
        first.type("vie")
        let second = DocumentHarness()
        second.document = first.document
        second.type("vieet")
        second.document.interrupt(client: first)
        second.type("j ")
        #expect(first.view.string == "vie")
        #expect(second.view.string == "việt ")
    }

    @Test func delayedNativeAcknowledgementCannotBeMistakenForACaretMove() {
        let host = DocumentHarness()
        host.prefersMarkedText = true
        host.delaysAcknowledgement = true
        host.type("vieetj")
        #expect(host.view.string == "việt")
        host.type("⌫t ")
        #expect(host.view.string == "việt ")
    }

    @Test func staleFrameQueriesAfterExplicitInsertionDoNotSplitOrLoseTheWord() {
        let host = DocumentHarness()
        host.keepsCachedQueriesAcrossKeys = true
        host.type("vieetj")
        #expect(host.view.string == "việt")
        #expect(host.view.selectedRange() == NSRange(location: 4, length: 0))
        #expect(!host.view.hasMarkedText())
        host.returningOldState = false // A renderer acknowledgement arrives before the caret move.
        host.view.setSelectedRange(NSRange(location: 2, length: 0))
        host.type("⌫")
        #expect(host.view.string == "vệt")
    }

    @Test func losingReadbackWithUnacknowledgedEditsCannotAuthorizeAnotherReplacement() {
        let host = DocumentHarness()
        host.keepsCachedQueriesAcrossKeys = true
        host.type("vie")
        host.readable = false
        host.type("etj ")
        #expect(host.view.string == "vieetj ")
    }

    @Test func aDelayedDeletionAcknowledgementStillAllowsRetypingAndChangingTone() {
        let host = DocumentHarness()
        host.keepsCachedQueriesAcrossKeys = true
        host.type("vieetj")
        host.returningOldState = false
        host.document.reconcile(with: host)
        host.type("⌫ts ")
        #expect(host.view.string == "viết ")
    }

    @Test func deleteRetypeAndAnIntermediateRendererFrameCannotRestoreStaleState() {
        let host = DocumentHarness()
        host.keepsCachedQueriesAcrossKeys = true
        host.type("vieetj")
        host.returningOldState = false
        host.document.reconcile(with: host)
        host.type("⌫t")
        host.oldText = "việ"
        host.oldSelection = DocumentRange(3, 0)
        host.returningOldState = true
        host.type("s ")
        #expect(host.view.string == "viết ")
    }

    @Test func nativeCachedQueriesAcrossKeysDoNotDropAnUnreadableWord() {
        let host = DocumentHarness()
        host.prefersMarkedText = true
        host.readable = false
        host.keepsCachedQueriesAcrossKeys = true
        host.delaysAcknowledgement = true
        host.type("vieetj")
        #expect(host.view.string == "việt")
        host.returningOldState = false
        host.flush()
        #expect(host.view.string == "việt")
        #expect(!host.view.hasMarkedText())
    }

    @Test func nativeRendererCorrectingAnInitialCachedAnchorDoesNotDropTheWord() {
        let host = DocumentHarness()
        host.prefersMarkedText = true
        host.keepsCachedQueriesAcrossKeys = true
        host.view.string = "trước "
        host.view.setSelectedRange(NSRange(location: 6, length: 0))
        host.oldSelection = DocumentRange(0, 0)
        host.oldText = ""
        host.returningOldState = true
        host.type("vieetj ")
        #expect(host.view.string == "trước việt ")
    }

    @Test func cachedWordEndCannotAnchorTheNextWordInsideThePreviousOne() {
        let host = DocumentHarness()
        host.keepsCachedQueriesAcrossKeys = true
        host.type("vieetj vie65t")
        #expect(host.view.string == "việt việt")
        #expect(!host.view.hasMarkedText())
        host.type(" reset server ")
        #expect(host.view.string == "việt việt reset server ")
        #expect(!host.view.hasMarkedText())
    }

    @Test func mixedMethodsAndEnglishStillComposeWithoutMarkedText() {
        let host = DocumentHarness()
        host.type("vieetj vie65t reset server ")
        #expect(host.view.string == "việt việt reset server ")
        #expect(!host.view.hasMarkedText())
    }

    @Test func missingReadbackFromTheStartUsesOwnedNativeComposition() {
        let host = DocumentHarness()
        host.readable = false
        host.type("vieetj⌫t ")
        #expect(host.view.string == "việt ")
        #expect(!host.view.hasMarkedText())
    }

    @Test func losingReadbackDoesNotOverwriteOrDuplicateTheCommittedPrefix() {
        let host = DocumentHarness()
        host.type("vie")
        host.readable = false
        host.type("etj ")
        host.flush()
        #expect(host.view.string == "vieetj ")
        host.readable = true
        host.type("vieetj ")
        #expect(host.view.string == "vieetj việt ")
    }

    @Test func nativeCommitAfterClientUnmarksDoesNotDuplicate() {
        let host = DocumentHarness()
        host.prefersMarkedText = true
        host.type("vieetj")
        #expect(host.view.hasMarkedText())
        host.view.unmarkText()
        host.flush()
        #expect(host.view.string == "việt")
    }

    @Test func pointerActionEndsNativeCompositionBeforeMovingTheCaret() {
        let host = DocumentHarness()
        host.prefersMarkedText = true
        host.type("vieetj")
        host.flush() // The same interrupt used before mouse-down/navigation.
        host.view.setSelectedRange(NSRange(location: 2, length: 0))
        host.type("⌫")
        #expect(host.view.string == "vệt")
    }

    @Test func programmaticSelectionInsideNativeCompositionCanBeReplaced() {
        let host = DocumentHarness()
        host.prefersMarkedText = true
        host.type("vieetj")
        host.view.setSelectedRange(NSRange(location: 1, length: 2))
        host.type("a")
        #expect(host.view.string == "vat")
    }

    @Test func sameLengthHostCorrectionIsPreserved() {
        let host = DocumentHarness()
        host.type("vieetj")
        host.view.unmarkText()
        host.view.string = "Việt"
        host.view.setSelectedRange(NSRange(location: 4, length: 0))
        host.flush()
        #expect(host.view.string == "Việt")
    }

    @Test func navigationDoesNotExpandAShortcutOrRestoreRawKeys() {
        let host = DocumentHarness()
        host.document.session.shortcuts = Shortcuts(["viêt": "expanded"])
        host.type("vieet")
        _ = host.document.handle(.boundary, client: host)
        #expect(host.view.string == "viêt")
        #expect(!host.view.hasMarkedText())
    }

    @Test func selectedTextAfterEmojiIsReplacedWithoutTouchingEitherNeighbour() {
        let host = DocumentHarness()
        let prefix = "👩🏽‍💻 "
        host.view.string = prefix + "cũ sau"
        host.view.setSelectedRange(NSRange(location: prefix.utf16.count, length: 2))
        host.type("vieetj ")
        #expect(host.view.string == prefix + "việt  sau")
    }

    @Test(arguments: [false, true])
    func navigationAndSelectionAfterEmojiPreserveSurroundingText(_ native: Bool) {
        let host = DocumentHarness()
        host.prefersMarkedText = native
        let prefix = "👩🏽‍💻 "
        host.view.string = prefix
        host.view.setSelectedRange(NSRange(location: prefix.utf16.count, length: 0))
        host.type("vieet")
        _ = host.document.handle(.boundary, client: host)
        host.view.setSelectedRange(NSRange(location: prefix.utf16.count + 2, length: 0))
        host.type("⌫")
        #expect(host.view.string == prefix + "vêt")
        host.type("i")
        _ = host.document.handle(.boundary, client: host)
        host.view.setSelectedRange(NSRange(location: prefix.utf16.count + 1, length: 2))
        host.type("x")
        host.flush()
        #expect(host.view.string == prefix + "vxt")
    }

}

@MainActor private final class DocumentHarness {
    let view = NSTextView(frame: NSRect(x: 0, y: 0, width: 500, height: 200))
    var document = DocumentSession(session: InputSession(engine: VitekEngine(options: .init(automaticallyDetectsMethod: true))))
    var readable = true
    var relativeNativeCaret = false
    var relativeFirstMarkOnly = false
    var incorrectReadback = false
    var ignoresExplicitRangeWhileMarked = false
    var markOffset = 0
    var retainsExplicitSelection = false
    var keepsCachedQueriesAcrossKeys = false
    var preservesCachedSnapshotAfterInsert = false
    var delaysAcknowledgement = false
    var returningOldState = false
    var oldSelection: DocumentRange?
    var oldMark: DocumentRange?
    var oldText = ""
    var prefersMarkedText = false
    var ignoresExplicitInsert = false
    var ignoresEmptyNativeInsert = false
    var forwardsBackspaceAsTextWhileMarked = false
    var nativeCaretLagsMark = false
    var nativeCaretLagsFirstMarkOnly = false
    var laggedNativeCaret: DocumentRange?

    init() {
        _ = NSApplication.shared
        view.isAutomaticSpellingCorrectionEnabled = false
        view.isAutomaticTextReplacementEnabled = false
        view.string = ""
        view.setSelectedRange(NSRange(location: 0, length: 0))
    }

    func type(_ keys: String) {
        for key in keys {
            if !keepsCachedQueriesAcrossKeys { returningOldState = false }
            let output = document.handle(key == "⌫" ? .backspace : .character(key), client: self, prefersMarkedText: prefersMarkedText)
            if output.passThrough {
                if key == "⌫", forwardsBackspaceAsTextWhileMarked, view.hasMarkedText() {
                    view.insertText("\u{08}", replacementRange: NSRange(location: NSNotFound, length: 0))
                } else if key == "⌫" { view.deleteBackward(nil) }
                else { view.insertText(String(key), replacementRange: NSRange(location: NSNotFound, length: 0)) }
            }
        }
    }

    func flush() { document.interrupt(client: self) }
}

extension DocumentHarness: DocumentClient {
    var documentID: ObjectIdentifier { ObjectIdentifier(self) }
    var selection: DocumentRange? {
        if nativeCaretLagsMark, view.hasMarkedText(), !nativeCaretLagsFirstMarkOnly || view.markedRange().length == 1 { return laggedNativeCaret }
        if relativeNativeCaret, view.hasMarkedText(), !relativeFirstMarkOnly || view.markedRange().length == 1 { return DocumentRange(view.markedRange().length, 0) }
        if returningOldState { return oldSelection }
        return DocumentRange(view.selectedRange().location, view.selectedRange().length)
    }
    var markedRange: DocumentRange? {
        if returningOldState { return oldMark }
        let range = view.markedRange()
        return range.length > 0 ? DocumentRange(range.location + markOffset, range.length) : nil
    }
    func text(in range: DocumentRange) -> String? {
        guard readable else { return nil }
        if incorrectReadback { return String(repeating: "?", count: range.length) }
        let string = (returningOldState && keepsCachedQueriesAcrossKeys ? oldText : view.string) as NSString
        guard range.end <= string.length else { return nil }
        return string.substring(with: NSRange(location: range.location, length: range.length))
    }
    func insert(_ text: String, replacing range: DocumentRange?) {
        if ignoresEmptyNativeInsert, text.isEmpty, range == nil, view.hasMarkedText() { return }
        if ignoresExplicitInsert, range != nil { return }
        if ignoresExplicitRangeWhileMarked, view.hasMarkedText() {
            view.insertText(text, replacementRange: NSRange(location: NSNotFound, length: 0))
            return
        }
        if preservesCachedSnapshotAfterInsert {
            // Electron drops a replacement addressed beyond the newly focused field.
            if let range, range.end > view.string.utf16.count { return }
            view.insertText(text, replacementRange: range.map { NSRange(location: $0.location, length: $0.length) }
                            ?? NSRange(location: NSNotFound, length: 0))
            return
        }
        let retained = retainsExplicitSelection && range?.length != 0 && range == selection
        let previousCaret = view.selectedRange()
        let previousText = view.string
        view.insertText(text, replacementRange: range.map { NSRange(location: $0.location, length: $0.length) }
                        ?? NSRange(location: NSNotFound, length: 0))
        if retained, let range {
            view.setSelectedRange(NSRange(location: range.location, length: text.utf16.count))
        }
        if keepsCachedQueriesAcrossKeys, range != nil {
            if !returningOldState {
                oldSelection = DocumentRange(previousCaret.location, previousCaret.length)
                oldMark = nil
                oldText = previousText
            }
            returningOldState = true
        } else if keepsCachedQueriesAcrossKeys {
            returningOldState = false
        }
    }
    func mark(_ text: String, replacing range: DocumentRange?) {
        laggedNativeCaret = DocumentRange(view.selectedRange().location, view.selectedRange().length)
        oldSelection = selection
        oldMark = markedRange
        view.setMarkedText(NSAttributedString(string: text), selectedRange: NSRange(location: text.utf16.count, length: 0),
                           replacementRange: range.map { NSRange(location: $0.location, length: $0.length) }
                           ?? NSRange(location: NSNotFound, length: 0))
        returningOldState = delaysAcknowledgement
    }
}
#endif
