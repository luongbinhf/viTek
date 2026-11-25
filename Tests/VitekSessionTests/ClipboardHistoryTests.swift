import Testing
import VitekSession

@Suite struct ClipboardHistoryTests {
    @Test func recordsDeduplicatesAndKeepsPinnedFirst() {
        var history = ClipboardHistory()
        let blankRecorded = history.record("   \n\t  ")
        let oversizedRecorded = history.record(String(repeating: "a", count: ClipboardHistory.maxItemUTF8Bytes + 1))
        #expect(!blankRecorded)
        #expect(!oversizedRecorded)

        let r1 = history.record("hello", timestamp: 10)
        let r2 = history.record("world", timestamp: 20)
        let p1 = history.addPinned("signature", timestamp: 5)
        #expect(r1 && r2 && p1)
        #expect(history.items.map(\.text) == ["signature", "world", "hello"])

        // Re-recording an unpinned item promotes it to top of unpinned without unpinning pinned items.
        let r3 = history.record("hello", timestamp: 30)
        #expect(r3)
        #expect(history.items.map(\.text) == ["signature", "hello", "world"])

        history.togglePin(text: "hello")
        #expect(history.pinnedItems.map(\.text) == ["hello", "signature"])
        history.clearUnpinned()
        #expect(history.items.map(\.text) == ["hello", "signature"])
    }

    @Test func searchesVietnameseAccentAndCaseInsensitively() {
        var history = ClipboardHistory()
        history.record("Cộng hòa Xã hội Chủ nghĩa Việt Nam", timestamp: 1)
        history.record("Swift 6 Native Input Method", timestamp: 2)

        #expect(history.search("viet nam").count == 1)
        #expect(history.search("VIỆT NAM").count == 1)
        #expect(history.search("swift").count == 1)
        #expect(history.search("").count == 2)
    }

    @Test func serializesAndMergesCloudSafely() {
        var local = ClipboardHistory()
        local.addPinned("Mẫu địa chỉ", timestamp: 10)
        local.record("Gần đây local", timestamp: 15)

        let roundTripped = ClipboardHistory(serialized: local.serialized())
        #expect(roundTripped == local)

        var merged = local
        merged.mergeCloud(
            pinned: [["text": "Mẫu remote", "pinned": "1", "ts": "20"], ["text": "Gần đây local", "pinned": "1", "ts": "12"]],
            recent: [["text": "Mới từ Mac", "pinned": "0", "ts": "25"]]
        )
        #expect(merged.pinnedItems.map(\.text) == ["Mẫu remote", "Gần đây local", "Mẫu địa chỉ"])
        #expect(merged.unpinnedItems.map(\.text) == ["Mới từ Mac"])
    }
}
