import Foundation

struct BuildLog: Identifiable {
    let id: UUID = .init()
    let bundleID: UUID
    var entries: [Entry] = []
    var state: State = .idle

    enum State { case idle, running, succeeded, failed }

    struct Entry: Identifiable {
        let id: UUID = .init()
        let kind: Kind
        let text: String
        let date: Date = .now

        enum Kind { case info, command, output, success, error }
    }

    mutating func append(_ kind: Entry.Kind, _ text: String) {
        entries.append(Entry(kind: kind, text: text))
    }
}
