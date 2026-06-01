import Testing
import Foundation
@testable import WindyKnits

@MainActor
@Suite("PatternStore")
struct PatternStoreTests {

    /// Each test gets its own UserDefaults suite so concurrent tests can't
    /// step on each other. The suite is wiped on init so the previous run's
    /// data doesn't leak in.
    private let defaults: UserDefaults

    init() {
        let suiteName = "PatternStoreTests-\(UUID().uuidString)"
        guard let d = UserDefaults(suiteName: suiteName) else {
            fatalError("Failed to create UserDefaults suite for test isolation")
        }
        for (key, _) in d.dictionaryRepresentation() {
            d.removeObject(forKey: key)
        }
        self.defaults = d
    }

    private func makeStore() -> PatternStore {
        PatternStore(defaults: defaults)
    }

    private func makeImported(id: String, title: String = "Imported",
                              status: ProjectStatus = .active) -> Project {
        Project(
            id: id,
            title: title,
            designer: "X",
            swatchHex: 0xff8800,
            yarn: "Yarn",
            color: "Pink",
            needles: "3mm",
            rowsDone: 0,
            rowsTotal: 100,
            lastWorked: "—",
            status: status
        )
    }

    @Test func newStoreStartsFromCleanDefaults() {
        let store = makeStore()
        #expect(store.imported.isEmpty)
    }

    @Test func addInsertsAtTopForNewProject() {
        let store = makeStore()
        store.add(makeImported(id: "i1", title: "First"))
        store.add(makeImported(id: "i2", title: "Second"))
        #expect(store.imported.map(\.id) == ["i2", "i1"])
    }

    @Test func addDedupesByIdAndMovesToTop() {
        let store = makeStore()
        store.add(makeImported(id: "i1", title: "First"))
        store.add(makeImported(id: "i2", title: "Second"))
        store.add(makeImported(id: "i1", title: "First updated"))
        #expect(store.imported.map(\.id) == ["i1", "i2"])
        #expect(store.imported[0].title == "First updated")
    }

    @Test func updatePreservesPositionForExistingProject() {
        let store = makeStore()
        store.add(makeImported(id: "i1", title: "One"))
        store.add(makeImported(id: "i2", title: "Two"))
        store.add(makeImported(id: "i3", title: "Three"))
        // Order is now [i3, i2, i1]. Update i1 — should stay at index 2.
        var edited = makeImported(id: "i1", title: "Edited")
        edited.notes = "edited note"
        store.update(edited)
        #expect(store.imported.map(\.id) == ["i3", "i2", "i1"])
        #expect(store.imported.last?.notes == "edited note")
    }

    @Test func updateInsertsAtTopWhenMissing() {
        let store = makeStore()
        store.add(makeImported(id: "i1", title: "Existing"))
        store.update(makeImported(id: "new", title: "Brand new"))
        #expect(store.imported.map(\.id) == ["new", "i1"])
    }

    @Test func projectByIDReturnsNilForUnknownID() {
        let store = makeStore()
        #expect(store.project(id: "no-such-id") == nil)
    }

    @Test func projectByIDReturnsNilAfterDelete() {
        let store = makeStore()
        store.add(makeImported(id: "i1"))
        store.delete("i1")
        #expect(store.project(id: "i1") == nil)
    }

    @Test func allProjectsHoldsOnlyImported() {
        let store = makeStore()
        store.add(makeImported(id: "i1"))
        store.add(makeImported(id: "i2"))
        #expect(store.allProjects().map(\.id) == ["i2", "i1"])
    }

    @Test func projectsInStatusFiltersByStatus() {
        let store = makeStore()
        store.add(makeImported(id: "a1", status: .active))
        store.add(makeImported(id: "q1", status: .queue))
        store.add(makeImported(id: "f1", status: .finished))
        let active = store.projects(in: .active)
        #expect(active.map(\.id) == ["a1"])
    }

    @Test func countsTotalsAcrossThreeStatuses() {
        let store = makeStore()
        store.add(makeImported(id: "a1", status: .active))
        store.add(makeImported(id: "a2", status: .active))
        store.add(makeImported(id: "q1", status: .queue))
        store.add(makeImported(id: "f1", status: .finished))
        let counts = store.counts()
        #expect(counts[.active] == 2)
        #expect(counts[.queue] == 1)
        #expect(counts[.finished] == 1)
    }

    @Test func setStatusMutatesInPlace() {
        let store = makeStore()
        store.add(makeImported(id: "i1", status: .active))
        store.setStatus("i1", to: .finished)
        #expect(store.imported.first?.status == .finished)
    }

    @Test func setStatusNoOpsForUnknownID() {
        let store = makeStore()
        store.setStatus("ghost", to: .finished)
        #expect(store.imported.isEmpty)
    }

    @Test func deleteDropsFromList() {
        let store = makeStore()
        store.add(makeImported(id: "i1"))
        store.delete("i1")
        #expect(!store.imported.contains(where: { $0.id == "i1" }))
    }

    @Test func stateRoundTripsThroughFreshInstance() {
        let store = makeStore()
        store.add(makeImported(id: "i1", title: "Persists"))
        store.setStatus("i1", to: .finished)

        let reloaded = PatternStore(defaults: defaults)
        #expect(reloaded.imported.map(\.id) == ["i1"])
        #expect(reloaded.imported.first?.status == .finished)
    }

    @Test func resetAllClearsImported() {
        let store = makeStore()
        store.add(makeImported(id: "i1"))
        store.resetAll()
        #expect(store.imported.isEmpty)
        let reloaded = PatternStore(defaults: defaults)
        #expect(reloaded.imported.isEmpty)
    }
}
