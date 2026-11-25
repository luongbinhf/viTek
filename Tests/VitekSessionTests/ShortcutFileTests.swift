import Testing
import VitekSession

@Suite struct ShortcutFileTests {
    @Test func multilineTemplatesRoundTripWithWindowsAndMacNewlines() {
        let entries = [ShortcutEntry(abbreviation: "qa", expansion: "Kết quả:\r\nĐạt\rGhi chú:\nAPI\\v1\tOK")]
        let parsed = ShortcutFile.parse(ShortcutFile.format(entries))
        #expect(parsed.entries == entries)
        #expect(parsed.rejectedLines.isEmpty)
    }

    @Test func readsTabAndSpaceSeparatedLines() {
        let parsed = ShortcutFile.parse("# danh sách\nko\tkhông\nvn   Việt Nam\n\n  \nhn\tHà Nội\n")
        #expect(parsed.entries == [
            ShortcutEntry(abbreviation: "ko", expansion: "không"),
            ShortcutEntry(abbreviation: "vn", expansion: "Việt Nam"),
            ShortcutEntry(abbreviation: "hn", expansion: "Hà Nội"),
        ])
        #expect(parsed.rejectedLines.isEmpty)
    }

    @Test func reportsLinesWithoutAPair() {
        let parsed = ShortcutFile.parse("ko\tkhông\nchỉ-một-từ\n\tthiếu chữ tắt\nvn\t\n")
        #expect(parsed.entries.map(\.abbreviation) == ["ko"])
        #expect(parsed.rejectedLines == [2, 3, 4])
    }

    @Test func acceptsWindowsAndOldMacLineEnds() {
        let parsed = ShortcutFile.parse("ko\tkhông\r\nvn\tViệt Nam\rhn\tHà Nội")
        #expect(parsed.entries.map(\.expansion) == ["không", "Việt Nam", "Hà Nội"])
    }

    @Test func formatThenParseKeepsEveryEntry() {
        let entries = [
            ShortcutEntry(abbreviation: "ko", expansion: "không"),
            ShortcutEntry(abbreviation: "dc", expansion: "địa chỉ:\n\tsố 1\\2"),
            ShortcutEntry(abbreviation: "", expansion: "bỏ qua"),
        ]
        let text = ShortcutFile.format(entries)
        #expect(text.contains("dc\tđịa chỉ:\\n\\tsố 1\\\\2\n"))
        #expect(ShortcutFile.parse(text).entries == Array(entries.prefix(2)))
    }

    @Test func importsColonSeparatedMacroFormat() {
        let macroText = "# macro header v1\n; comment\nko:không\nvn:Việt Nam\nmail:hello@example.com\n"
        let parsed = ShortcutFile.parse(macroText)
        #expect(parsed.entries == [
            ShortcutEntry(abbreviation: "ko", expansion: "không"),
            ShortcutEntry(abbreviation: "vn", expansion: "Việt Nam"),
            ShortcutEntry(abbreviation: "mail", expansion: "hello@example.com"),
        ])
        #expect(parsed.rejectedLines.isEmpty)
    }

    @Test func importsAndFormatsCSVWithQuotesAndCommas() {
        let csv = "abbreviation,expansion\nko,không\n\"dc\",\"Hà Nội, \"\"Việt Nam\"\"\"\n"
        let parsed = ShortcutFile.parse(csv)
        #expect(parsed.entries == [
            ShortcutEntry(abbreviation: "ko", expansion: "không"),
            ShortcutEntry(abbreviation: "dc", expansion: "Hà Nội, \"Việt Nam\""),
        ])
        #expect(parsed.rejectedLines.isEmpty)
        let roundTrip = ShortcutFile.parse(ShortcutFile.formatCSV(parsed.entries))
        #expect(roundTrip.entries == parsed.entries)
    }

    @Test func tabSeparatedURLIsNotSplitAtColon() {
        let parsed = ShortcutFile.parse("web\thttps://apple.com\n")
        #expect(parsed.entries == [ShortcutEntry(abbreviation: "web", expansion: "https://apple.com")])
    }
}
