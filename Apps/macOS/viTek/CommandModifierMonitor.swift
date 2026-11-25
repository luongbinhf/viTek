import AppKit
import os

/// Tracks actual modifier transitions, independently of IMK's delayed duplicate callbacks.
/// No text keys are observed, suppressed, or replayed.
struct CommandPressState {
    private(set) var generation: UInt64 = 0
    private(set) var isDown = false
    private var presses: [(time: TimeInterval, generation: UInt64)] = []

    mutating func observe(commandDown: Bool, at timestamp: TimeInterval = 0) {
        if commandDown && !isDown {
            generation &+= 1
            presses.append((timestamp, generation))
            if presses.count > 32 { presses.removeFirst() }
        }
        isDown = commandDown
    }

    // The tap can run ahead of IMK. Associate each callback with the press that
    // existed when that event occurred, never with a future queued press.
    func generation(at timestamp: TimeInterval) -> UInt64 {
        presses.last(where: { $0.time <= timestamp })?.generation ?? 0
    }
}

struct CommandPressGate {
    private var consumed: UInt64 = 0

    mutating func reset(to generation: UInt64) { consumed = max(consumed, generation) }

    mutating func recordKey(command: Bool, generation: UInt64) {
        // IMK can re-create an older text event with a newer timestamp. Only an
        // actual Command shortcut proves that its composition boundary has passed.
        if command { reset(to: generation) }
    }

    mutating func consumeIf(_ isCommandDown: Bool, generation: UInt64) -> Bool {
        isCommandDown && consume(generation)
    }

    mutating func consume(_ generation: UInt64) -> Bool {
        guard generation > consumed else { return false }
        consumed = generation
        return true
    }
}

/// The synchronous tap updates a tiny unfair-locked counter before macOS dispatches the event.
/// All IMK/document work stays on the main thread. If the tap is unavailable, typing
/// retains its permission-free path and uses the conservative held-Command fallback.
final class CommandModifierMonitor: @unchecked Sendable {
    private struct LockedState {
        var press = CommandPressState()
        var available = false
        var started = false
    }

    static let shared = CommandModifierMonitor()
    private let state = OSAllocatedUnfairLock(initialState: LockedState())
    private var tap: CFMachPort?

    var snapshot: (available: Bool, generation: UInt64) {
        state.withLock { ($0.available, $0.press.generation) }
    }

    func snapshot(at timestamp: TimeInterval) -> (available: Bool, generation: UInt64) {
        state.withLock { ($0.available, $0.press.generation(at: timestamp)) }
    }

    func start() {
        let shouldStart = state.withLock { locked -> Bool in
            guard !locked.started else { return false }
            locked.started = true
            return true
        }
        guard shouldStart else { return }
        Thread.detachNewThread { [self] in run() }
    }

    private func run() {
        guard let port = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
            options: .defaultTap, eventsOfInterest: CGEventMask(1) << CGEventType.flagsChanged.rawValue,
            callback: { _, type, event, context in
                guard let context else { return Unmanaged.passUnretained(event) }
                let monitor = Unmanaged<CommandModifierMonitor>.fromOpaque(context).takeUnretainedValue()
                monitor.receive(type, event: event)
                return Unmanaged.passUnretained(event)
            }, userInfo: Unmanaged.passUnretained(self).toOpaque()) else { return }
        tap = port
        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0) else { return }
        state.withLock { locked in
            locked.press.observe(commandDown: CGEventSource.flagsState(.combinedSessionState).contains(.maskCommand),
                                 at: ProcessInfo.processInfo.systemUptime)
            locked.available = true
        }
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
        CFRunLoopRun()
        state.withLock { $0.available = false }
    }

    private func receive(_ type: CGEventType, event: CGEvent) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            // A gap cannot provide reliable identity. Fall back until a fresh transition.
            state.withLock { locked in
                locked.available = false
                locked.press.observe(commandDown: CGEventSource.flagsState(.combinedSessionState).contains(.maskCommand),
                                     at: ProcessInfo.processInfo.systemUptime)
            }
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return
        }
        guard type == .flagsChanged else { return }
        let commandDown = event.flags.contains(.maskCommand)
        let timestamp = Double(event.timestamp) / 1_000_000_000
        state.withLock { locked in
            locked.press.observe(commandDown: commandDown, at: timestamp)
            locked.available = true
        }
    }
}
