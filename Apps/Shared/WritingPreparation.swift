import Foundation

/// One unused session, owned by one writing screen. A consumed session is never cached again.
@MainActor final class WritingPreparation<Resource> {
    private var resource: Resource?
    private var deadline: ContinuousClock.Instant?
    private var expiry: Task<Void, Never>?
    private let lifetime: Duration
    private let now: () -> ContinuousClock.Instant

    init(lifetime: Duration = .seconds(30), now: @escaping () -> ContinuousClock.Instant = { .now }) {
        precondition(lifetime > .zero)
        self.lifetime = lifetime
        self.now = now
    }

    deinit { expiry?.cancel() }

    var isPrepared: Bool {
        discardIfExpired()
        return resource != nil
    }

    func prepare(_ make: () -> Resource) {
        guard !isPrepared else { return }
        resource = make()
        deadline = now().advanced(by: lifetime)
        expiry = Task { @MainActor [weak self, lifetime] in
            do { try await Task.sleep(for: lifetime) }
            catch { return }
            guard !Task.isCancelled else { return }
            self?.discard()
        }
    }

    func take() -> Resource? {
        discardIfExpired()
        defer { discard() }
        return resource
    }

    func discard() {
        expiry?.cancel()
        expiry = nil
        resource = nil
        deadline = nil
    }

    private func discardIfExpired() {
        if let deadline, now() >= deadline { discard() }
    }
}
