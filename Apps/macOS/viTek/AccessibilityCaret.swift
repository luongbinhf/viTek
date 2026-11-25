import AppKit
import ApplicationServices

/// The caret's position read through the Accessibility API, for clients whose own answer cannot be
/// trusted. Chromium (Chrome, and Electron apps such as Claude, Slack, VS Code) gives an input method
/// caret geometry only while there is marked text. While viTek types directly it answers `firstRect`
/// with garbage, and the line box with where the caret was when the field got focus. Its
/// accessibility tree knows where the caret is.
///
/// Needs the user to allow viTek under Privacy & Security → Accessibility; until then the position is unavailable.
actor AccessibilityCaret {
    private static let shared = AccessibilityCaret()
    private var askedForTree: Set<pid_t> = []

    static var isAllowed: Bool { AXIsProcessTrusted() }

    /// Shows the system prompt that leads to the Accessibility list in System Settings.
    static func requestAccess() {
        // The value of `kAXTrustedCheckOptionPrompt`, which Swift 6 will not read as a global.
        _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }

    enum Lookup: Sendable {
        case found(NSRect)
        case waitingForFocus
        case unavailable
    }

    /// Chromium can return no focused element while it builds its accessibility tree.
    @MainActor static func rect(inAppWith bundleID: String?) async -> Lookup {
        guard let bundleID, let app = NSWorkspace.shared.frontmostApplication, app.bundleIdentifier == bundleID,
              let primary = NSScreen.screens.first else { return .unavailable }
        let pid = app.processIdentifier
        let position = await shared.lookup(pid: pid)
        guard !Task.isCancelled, NSWorkspace.shared.frontmostApplication?.processIdentifier == pid
        else { return .unavailable }
        if case .found(var box) = position {
            box.origin.y = primary.frame.maxY - box.maxY
            return .found(box)
        }
        return position
    }

    private func lookup(pid: pid_t) -> Lookup {
        guard !Task.isCancelled else { return .unavailable }
        guard Self.isAllowed else { return fail("accessibility permission unavailable") }
        let application = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(application, 0.15)
        if !askedForTree.contains(pid) {
            // Chromium builds its accessibility tree only once something asks for it.
            if AXUIElementSetAttributeValue(application, "AXManualAccessibility" as CFString, kCFBooleanTrue) == .success {
                askedForTree.insert(pid)
            }
        }
        var focused: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(application, kAXFocusedUIElementAttribute as CFString, &focused)
        if error == .noValue {
            Diagnostics.log("ax: waiting for focused element")
            return .waitingForFocus
        }
        guard error == .success, let focused, CFGetTypeID(focused) == AXUIElementGetTypeID()
        else { return fail("no focused element (\(error.rawValue))") }
        let field = focused as! AXUIElement
        AXUIElementSetMessagingTimeout(field, 0.15)
        guard !Task.isCancelled else { return .unavailable }
        if let marker = value(field, "AXSelectedTextMarkerRange"),
           let box = bounds(field, "AXBoundsForTextMarkerRange", marker) {
            return .found(NSRect(x: box.minX, y: box.minY, width: 0, height: box.height))
        }
        guard !Task.isCancelled else { return .unavailable }
        // Without text markers: the box of the character before the caret.
        guard let selected = value(field, kAXSelectedTextRangeAttribute), CFGetTypeID(selected) == AXValueGetTypeID()
        else { return fail("no selected range") }
        var range = CFRange()
        guard AXValueGetValue(selected as! AXValue, .cfRange, &range), range.location > 0
        else { return fail("selected range \(range.location)") }
        var before = CFRange(location: range.location - 1, length: 1)
        guard let parameter = AXValueCreate(.cfRange, &before),
              let box = bounds(field, kAXBoundsForRangeParameterizedAttribute, parameter)
        else { return fail("no bounds for range") }
        return .found(NSRect(x: box.maxX, y: box.minY, width: 0, height: box.height))
    }

    private func fail(_ reason: @autoclosure () -> String) -> Lookup {
        Diagnostics.log("ax: \(reason())")
        return .unavailable
    }

    private func value(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value
    }

    /// Returns a line box in Accessibility's top-left screen coordinates.
    private func bounds(_ element: AXUIElement, _ attribute: String, _ parameter: CFTypeRef) -> NSRect? {
        var value: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(element, attribute as CFString, parameter, &value) == .success,
              let value, CFGetTypeID(value) == AXValueGetTypeID()
        else { return nil }
        var box = CGRect.zero
        guard AXValueGetValue(value as! AXValue, .cgRect, &box), box.height > 1, box.height < 400
        else { return nil }
        return box
    }
}
