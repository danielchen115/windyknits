import Testing
import Foundation
@testable import WindyKnits

@MainActor
@Suite("SharedStore", .serialized)
struct SharedStoreTests {

    init() {
        TestState.wipeAll()
    }

    @Test func keysAreScopedByProject() {
        #expect(SharedStore.Keys.rows("p1")     == "counter.p1.rows")
        #expect(SharedStore.Keys.stitches("p1") == "counter.p1.stitches")
        #expect(SharedStore.Keys.linked("p1")   == "counter.p1.linked")
        #expect(SharedStore.Keys.active("p1")   == "counter.p1.active")
        #expect(SharedStore.Keys.history("p1")  == "counter.p1.history")
        #expect(SharedStore.Keys.rowTexts("p1") == "counter.p1.rowTexts")
    }

    @Test func keysAreDistinctAcrossProjects() {
        #expect(SharedStore.Keys.rows("alpha") != SharedStore.Keys.rows("beta"))
    }

    @Test func usesAppGroupSuite() {
        #expect(SharedStore.appGroup == "group.dc.knitting.shared")
    }

    @Test func rowTextRoundTripsThroughDefaults() {
        SharedStore.setRowTexts([1: "K all", 2: "P all", 3: "K2tog"], projectId: "test")
        #expect(SharedStore.rowText(forRow: 1, projectId: "test") == "K all")
        #expect(SharedStore.rowText(forRow: 2, projectId: "test") == "P all")
        #expect(SharedStore.rowText(forRow: 3, projectId: "test") == "K2tog")
    }

    @Test func rowTextReturnsNilForUnseededProject() {
        #expect(SharedStore.rowText(forRow: 1, projectId: "missing") == nil)
    }

    @Test func rowTextReturnsNilForRowOutsideSeededRange() {
        SharedStore.setRowTexts([1: "first"], projectId: "test")
        #expect(SharedStore.rowText(forRow: 2, projectId: "test") == nil)
    }

    @Test func rowTextReturnsNilForZeroOrNegativeRowNumber() {
        SharedStore.setRowTexts([1: "first"], projectId: "test")
        #expect(SharedStore.rowText(forRow: 0, projectId: "test") == nil)
        #expect(SharedStore.rowText(forRow: -3, projectId: "test") == nil)
    }

    @Test func setRowTextsOverwritesPreviousSnapshot() {
        SharedStore.setRowTexts([1: "old", 2: "old"], projectId: "test")
        SharedStore.setRowTexts([1: "new"], projectId: "test")
        #expect(SharedStore.rowText(forRow: 1, projectId: "test") == "new")
        // Row 2 only existed in the first snapshot — it should be gone now.
        #expect(SharedStore.rowText(forRow: 2, projectId: "test") == nil)
    }

    @Test func migrationCopiesCounterKeysFromStandardDefaults() {
        UserDefaults.standard.set(42, forKey: "counter.legacy.rows")
        defer { UserDefaults.standard.removeObject(forKey: "counter.legacy.rows") }
        // Ensure shared store doesn't have it yet, and isn't flagged as migrated.
        SharedStore.defaults.removeObject(forKey: "counter.legacy.rows")
        SharedStore.defaults.removeObject(forKey: "counter.migratedToAppGroup.v1")

        SharedStore.migrateFromStandardIfNeeded()

        #expect(SharedStore.defaults.integer(forKey: "counter.legacy.rows") == 42)
        #expect(SharedStore.defaults.bool(forKey: "counter.migratedToAppGroup.v1") == true)
    }

    @Test func migrationDoesNotOverwriteExistingAppGroupKeys() {
        UserDefaults.standard.set(1, forKey: "counter.shared.rows")
        defer { UserDefaults.standard.removeObject(forKey: "counter.shared.rows") }
        SharedStore.defaults.set(99, forKey: "counter.shared.rows")
        SharedStore.defaults.removeObject(forKey: "counter.migratedToAppGroup.v1")

        SharedStore.migrateFromStandardIfNeeded()

        #expect(SharedStore.defaults.integer(forKey: "counter.shared.rows") == 99)
    }

    @Test func migrationIsIdempotent() {
        UserDefaults.standard.set(1, forKey: "counter.once.rows")
        defer { UserDefaults.standard.removeObject(forKey: "counter.once.rows") }
        SharedStore.defaults.removeObject(forKey: "counter.once.rows")
        SharedStore.defaults.removeObject(forKey: "counter.migratedToAppGroup.v1")

        SharedStore.migrateFromStandardIfNeeded()
        // Mutate the app-group copy and run the migration again — it should NOT
        // be overwritten because the migration flag has already been set.
        SharedStore.defaults.set(77, forKey: "counter.once.rows")
        SharedStore.migrateFromStandardIfNeeded()
        #expect(SharedStore.defaults.integer(forKey: "counter.once.rows") == 77)
    }
}

@MainActor
@Suite("CounterActivityAttributes")
struct CounterActivityAttributesTests {

    @Test func contentStateCodableRoundTrips() throws {
        let state = CounterActivityAttributes.ContentState(rows: 17, currentRowText: "Knit all")
        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(CounterActivityAttributes.ContentState.self, from: data)
        #expect(decoded == state)
    }

    @Test func contentStateDefaultsCurrentRowTextToNil() {
        let state = CounterActivityAttributes.ContentState(rows: 1)
        #expect(state.currentRowText == nil)
    }

    @Test func legacyEncodedStateWithoutCurrentRowTextStillDecodes() throws {
        let legacyJSON = #"{"rows": 5}"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(CounterActivityAttributes.ContentState.self, from: legacyJSON)
        #expect(decoded.rows == 5)
        #expect(decoded.currentRowText == nil)
    }
}
