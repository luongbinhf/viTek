import Foundation

@main struct CommandPressCheck {
    static func main() {
        var state = CommandPressState()
        var gate = CommandPressGate()
        var checks = 0
        func check(_ value: Bool, _ name: String) {
            guard value else { fatalError("FAIL \(name)") }
            checks += 1
        }
        gate.reset(to: state.generation)
        check(!gate.consumeIf(true, generation: state.generation), "no old press on activation")
        state.observe(commandDown: true)
        state.observe(commandDown: false)
        check(gate.consumeIf(true, generation: state.generation), "released Command still ends previous composition")
        check(!gate.consumeIf(true, generation: state.generation), "late duplicate cannot split new word")
        state.observe(commandDown: true)
        check(!gate.consumeIf(false, generation: state.generation), "Shift callback cannot consume Command")
        check(gate.consumeIf(true, generation: state.generation), "next real press works")
        state.observe(commandDown: true)
        check(!gate.consumeIf(true, generation: state.generation), "second Command or Shift while held is not new press")
        state.observe(commandDown: false)
        state.observe(commandDown: false)
        check(!gate.consumeIf(true, generation: state.generation), "other modifier releases do not renew press")
        state.observe(commandDown: true)
        gate.reset(to: state.generation)
        check(!gate.consumeIf(true, generation: state.generation), "keyDown invalidates delayed first callback")
        state.observe(commandDown: false)
        for _ in 0..<10000 {
            state.observe(commandDown: true)
            state.observe(commandDown: false)
            check(gate.consumeIf(true, generation: state.generation), "rapid repeated press")
            check(!gate.consumeIf(true, generation: state.generation), "rapid repeated duplicate")
        }
        var queued = CommandPressState()
        var queuedGate = CommandPressGate()
        // The event tap already saw Command, but IMK is still handling an older letter.
        queued.observe(commandDown: true, at: 20)
        queued.observe(commandDown: false, at: 21)
        queuedGate.reset(to: queued.generation(at: 19))
        check(queuedGate.consumeIf(true, generation: queued.generation(at: 20)), "older letter cannot consume future Command press")
        queued.observe(commandDown: true, at: 30)
        queued.observe(commandDown: false, at: 31)
        check(!queuedGate.consumeIf(true, generation: queued.generation(at: 20)), "old callback must not borrow newer press identity")
        check(queuedGate.consumeIf(true, generation: queued.generation(at: 30)), "new press keeps its own identity")
        queuedGate.reset(to: queued.generation(at: 20))
        check(!queuedGate.consumeIf(true, generation: queued.generation(at: 30)), "old key cannot rewind consumed press")
        check(!queuedGate.consumeIf(true, generation: queued.generation(at: 20)), "old callback cannot rewind consumed press")
        for time in 40..<80 {
            queued.observe(commandDown: true, at: Double(time))
            queued.observe(commandDown: false, at: Double(time) + 0.5)
        }
        check(queued.generation(at: 20) == 0, "evicted history cannot masquerade as a new press")
        check(queuedGate.consumeIf(true, generation: queued.generation(at: 79)), "latest press survives bounded history")
        var recreatedGate = CommandPressGate()
        recreatedGate.recordKey(command: false, generation: 1)
        check(recreatedGate.consumeIf(true, generation: 1), "re-created text timestamp cannot consume next Command")
        recreatedGate.recordKey(command: true, generation: 2)
        check(!recreatedGate.consumeIf(true, generation: 2), "actual shortcut invalidates delayed callback")
        print("PASS \(checks) Command press identity assertions")
    }
}
