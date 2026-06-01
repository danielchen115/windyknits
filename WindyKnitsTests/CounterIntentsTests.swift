import Testing
import Foundation
@testable import WindyKnits

@MainActor
@Suite("CounterMutation.appendHistory", .serialized)
struct CounterMutationHistoryTests {

    private let projectId = "test-history"

    init() {
        SharedStore.defaults.removeObject(forKey: SharedStore.Keys.history(projectId))
    }

    private struct Entry: Codable {
        let n: Int
        let timestamp: Date
        let sts: Int
    }

    private func readHistory() -> [Entry] {
        guard let s = SharedStore.defaults.string(forKey: SharedStore.Keys.history(projectId)),
              let data = s.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([Entry].self, from: data)
        else { return [] }
        return decoded
    }

    @Test func appendsFirstEntryToEmptyHistory() {
        CounterMutation.appendHistory(rowNumber: 1, projectId: projectId)
        let history = readHistory()
        #expect(history.count == 1)
        #expect(history.first?.n == 1)
    }

    @Test func appendsToExistingHistoryPreservingOrder() {
        for n in 1...5 {
            CounterMutation.appendHistory(rowNumber: n, projectId: projectId)
        }
        let history = readHistory()
        #expect(history.map(\.n) == [1, 2, 3, 4, 5])
    }

    @Test func capsHistoryAtFiftyEntries() {
        for n in 1...75 {
            CounterMutation.appendHistory(rowNumber: n, projectId: projectId)
        }
        let history = readHistory()
        #expect(history.count == 50)
        // The cap keeps the LAST 50 entries (rows 26 through 75).
        #expect(history.first?.n == 26)
        #expect(history.last?.n == 75)
    }

    @Test func recoversGracefullyFromCorruptedStoredJSON() {
        SharedStore.defaults.set("garbage{{{", forKey: SharedStore.Keys.history(projectId))
        CounterMutation.appendHistory(rowNumber: 9, projectId: projectId)
        let history = readHistory()
        // Corrupt input is treated as empty — only the new entry survives.
        #expect(history.count == 1)
        #expect(history.first?.n == 9)
    }
}
