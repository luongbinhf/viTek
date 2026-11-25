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
        let p1 = history.addPinned("signature", alias: "Chữ ký email", timestamp: 5)
        #expect(r1 && r2 && p1)
        #expect(history.items.map(\.text) == ["signature", "world", "hello"])
        #expect(history.items.first?.alias == "Chữ ký email")

        // Re-recording an unpinned item promotes it to top of unpinned without unpinning pinned items.
        let r3 = history.record("hello", timestamp: 30)
        #expect(r3)
        #expect(history.items.map(\.text) == ["signature", "hello", "world"])

        history.togglePin(text: "hello")
        #expect(history.pinnedItems.map(\.text) == ["hello", "signature"])
        history.clearUnpinned()
        #expect(history.items.map(\.text) == ["hello", "signature"])
    }

    @Test func classifiesSemanticContentAndHexColors() {
        #expect(ClipboardItem(text: "https://luongbinhf.github.io/viTek/").kind == .url)
        #expect(ClipboardItem(text: "support@vitek.dev").kind == .email)
        #expect(ClipboardItem(text: "+84 912 345 678").kind == .phone)
        #expect(ClipboardItem(text: "482910").kind == .otp)
        #expect(ClipboardItem(text: "git status --short").kind == .code)
        #expect(ClipboardItem(text: "func demo() {\n    return\n}").kind == .code)
        #expect(ClipboardItem(text: "Dòng 1\nDòng 2\nDòng 3").kind == .multiline)
        #expect(ClipboardItem(text: "Xin chào Việt Nam").kind == .text)

        let hex = ClipboardItem(text: "#0B66E4")
        #expect(hex.kind == .hexColor)
        #expect(hex.parsedHexColor == ClipboardRGBColor(r: 11, g: 102, b: 228))

        let shortHex = ClipboardItem(text: "#F90")
        #expect(shortHex.kind == .hexColor)
        #expect(shortHex.parsedHexColor == ClipboardRGBColor(r: 255, g: 153, b: 0))
    }

    @Test func filtersReordersEditsAndDetectsSmartPaste() {
        var history = ClipboardHistory()
        let p1 = history.addPinned("0909123456", alias: "Số điện thoại", timestamp: 100)
        let p2 = history.addPinned("https://github.com/luongbinhf/viTek", alias: "Kho viTek", timestamp: 200)
        let r1 = history.record("#16A34A", timestamp: 300)
        let r2 = history.record("839201", timestamp: 580)
        #expect(p1 && p2 && r1 && r2)

        #expect(history.filter(.pinned).count == 2)
        #expect(history.filter(.linksAndContacts).count == 3)
        #expect(history.filter(.codeAndColor).map(\.text) == ["#16A34A"])
        #expect(history.filter(.all, query: "kho vitek").map(\.text) == ["https://github.com/luongbinhf/viTek"])

        history.movePinned(from: 1, to: 0)
        #expect(history.pinnedItems.map(\.alias) == ["Số điện thoại", "Kho viTek"])

        let updated = history.updateItem(oldText: "0909123456", newText: "+84909123456", alias: "Hotline")
        #expect(updated)
        #expect(history.pinnedItems.first?.text == "+84909123456")
        #expect(history.pinnedItems.first?.alias == "Hotline")

        let smart = history.smartPasteCandidate(pasteboardText: nil, now: 600, maxAgeSeconds: 90)
        #expect(smart?.text == "839201")
        #expect(smart?.smartChipTitle == "Dán mã 839201")

        let liveSmart = history.smartPasteCandidate(pasteboardText: "https://apple.com", now: 600)
        #expect(liveSmart?.text == "https://apple.com")
        #expect(liveSmart?.kind == .url)
    }

    @Test func searchesVietnameseAccentAndCaseInsensitivelyIncludingAliases() {
        var history = ClipboardHistory()
        history.record("Cộng hòa Xã hội Chủ nghĩa Việt Nam", timestamp: 1)
        let added = history.addPinned("190010012345", alias: "Tài khoản công ty", timestamp: 2)
        #expect(added)

        #expect(history.search("viet nam").count == 1)
        #expect(history.search("tai khoan").map(\.alias) == ["Tài khoản công ty"])
        #expect(history.search("").count == 2)
    }

    @Test func serializesAndMergesCloudSafelyWithAliases() {
        var local = ClipboardHistory()
        let added = local.addPinned("Mẫu địa chỉ", alias: "Văn phòng", timestamp: 10)
        let recorded = local.record("Gần đây local", timestamp: 15)
        #expect(added && recorded)

        let roundTripped = ClipboardHistory(serialized: local.serialized())
        #expect(roundTripped == local)

        var merged = local
        merged.mergeCloud(
            pinned: [
                ["text": "Mẫu remote", "alias": "Ký tên", "pinned": "1", "ts": "20"],
                ["text": "Gần đây local", "pinned": "1", "ts": "12"],
            ],
            recent: [["text": "Mới từ Mac", "pinned": "0", "ts": "25"]]
        )
        #expect(merged.pinnedItems.map(\.text) == ["Mẫu remote", "Gần đây local", "Mẫu địa chỉ"])
        #expect(merged.pinnedItems.first?.alias == "Ký tên")
        #expect(merged.unpinnedItems.map(\.text) == ["Mới từ Mac"])
    }
}
