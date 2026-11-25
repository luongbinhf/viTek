import AppKit
import InputMethodKit
import VitekSession

/// No bundle-ID routing for editing: each field must demonstrate readable document ranges.
@MainActor struct IMKDocumentClient: DocumentClient {
    let client: any IMKTextInput
    let styledText: (String) -> NSAttributedString
    var documentID: ObjectIdentifier { ObjectIdentifier(client as AnyObject) }

    var selection: DocumentRange? {
        let range = client.selectedRange()
        return DocumentRange(range.location, range.length)
    }

    var markedRange: DocumentRange? {
        let range = client.markedRange()
        guard range.length > 0 else { return nil }
        return DocumentRange(range.location, range.length)
    }

    func text(in range: DocumentRange) -> String? {
        Self.verifiedText(in: range, documentLength: client.length(), selection: selection) {
            client.attributedSubstring(from: $0)?.string
        }
    }

    static func verifiedText(in range: DocumentRange, documentLength: Int, selection: DocumentRange?,
                             substring: (NSRange) -> String?) -> String? {
        // IMK falls back to selected text when TSMDocumentAccess is unavailable. Matching
        // string length alone therefore does not prove the requested document range exists.
        guard documentLength >= 0, documentLength != NSNotFound, range.end <= documentLength else { return nil }
        let result = substring(NSRange(location: range.location, length: range.length))
        if let result, result.utf16.count == range.length { return result }
        if range.length == 0, selection == range {
            if range.location > 0,
               substring(NSRange(location: range.location - 1, length: 1))?.utf16.count == 1 { return "" }
            if documentLength >= 0, documentLength != NSNotFound, range.location <= documentLength { return "" }
        }
        return nil
    }

    func insert(_ text: String, replacing range: DocumentRange?) {
        client.insertText(text, replacementRange: nativeRange(range))
    }

    func mark(_ text: String, replacing range: DocumentRange?) {
        client.setMarkedText(styledText(text), selectionRange: NSRange(location: text.utf16.count, length: 0),
                             replacementRange: nativeRange(range))
    }

    private func nativeRange(_ range: DocumentRange?) -> NSRange {
        range.map { NSRange(location: $0.location, length: $0.length) }
            ?? NSRange(location: NSNotFound, length: NSNotFound)
    }
}
