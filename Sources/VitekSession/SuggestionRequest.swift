/// A request belongs to one focus/typing revision, not merely a caret offset.
/// Hosts invalidate on typing, navigation, activation and deactivation. Comparing the exact
/// readable context also catches host edits that arrive without a keyboard callback.
public struct SuggestionRequest: Sendable {
    public struct Snapshot: Equatable, Sendable {
        public let client: ObjectIdentifier
        public let caret: Int
        public let prefix: String
        public let context: String?

        public init(client: ObjectIdentifier, caret: Int, prefix: String, context: String?) {
            self.client = client
            self.caret = caret
            self.prefix = prefix
            self.context = context
        }
    }

    public struct Ticket: Sendable {
        fileprivate let revision: UInt64
        fileprivate let snapshot: Snapshot
    }

    private var revision: UInt64 = 0
    public init() {}

    public mutating func invalidate() { revision &+= 1 }

    public mutating func begin(_ snapshot: Snapshot) -> Ticket {
        invalidate()
        return Ticket(revision: revision, snapshot: snapshot)
    }

    public func isCurrent(_ ticket: Ticket, snapshot: Snapshot) -> Bool {
        ticket.revision == revision && ticket.snapshot == snapshot
    }
}
