import Foundation

@main struct WritingPreparationCheck {
    @MainActor static func main() async throws {
        var checks = 0
        func check(_ condition: Bool, _ message: String) {
            precondition(condition, message)
            checks += 1
        }
        final class Resource { var draft = "" }
        var now = ContinuousClock.now
        let slot = WritingPreparation<Resource>(now: { now })
        var creations = 0
        func make() -> Resource { creations += 1; return Resource() }
        slot.prepare(make)
        for _ in 0..<100 { slot.prepare(make) }
        check(creations == 1, "Typing must not repeatedly prepare models")
        let first = slot.take()!
        first.draft = "private draft from request A"
        check(slot.take() == nil, "A used transcript must never be reused")
        slot.prepare(make)
        let second = slot.take()!
        check(first !== second && second.draft.isEmpty, "Requests must not inherit another draft")
        slot.prepare(make)
        now = now.advanced(by: .seconds(30))
        check(slot.take() == nil, "Prepared session expires at its deadline")
        slot.prepare(make)
        slot.discard()
        check(!slot.isPrepared && slot.take() == nil, "Leaving a screen releases preparation")
        for _ in 0..<1000 {
            slot.prepare(make)
            check(slot.take() != nil && slot.take() == nil, "Each request owns exactly one unused resource")
        }
        let timed = WritingPreparation<Resource>(lifetime: .milliseconds(10))
        weak var held: Resource?
        timed.prepare { let item = Resource(); held = item; return item }
        check(held != nil, "Unused session is retained during preparation")
        let timeout = ContinuousClock.now.advanced(by: .seconds(2))
        while held != nil, ContinuousClock.now < timeout { try await Task.sleep(for: .milliseconds(10)) }
        check(held == nil, "Unused session must expire without another interaction")
        for thermal: ProcessInfo.ThermalState in [.nominal, .fair, .serious, .critical] {
            check(!WritingSuggestion.allowsPrewarming(modelReady: false, lowPower: false, thermal: thermal), "No model means no prewarm")
            check(!WritingSuggestion.allowsPrewarming(modelReady: true, lowPower: true, thermal: thermal), "Low Power Mode disables speculation")
            check(WritingSuggestion.allowsPrewarming(modelReady: true, lowPower: false, thermal: thermal) == (thermal == .nominal || thermal == .fair), "Thermal policy")
        }
        print("PASS \(checks) writing preparation assertions: isolation, reuse, expiry, release, power and thermal policy")
    }
}
