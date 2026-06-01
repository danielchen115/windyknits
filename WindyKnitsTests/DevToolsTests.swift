import Testing
import Foundation
@testable import WindyKnits

@MainActor
@Suite("DevTools", .serialized)
struct DevToolsTests {

    init() {
        TestState.wipeAll()
    }

    @Test func seedSampleProjectsLoadsTheBundledFixtures() {
        DevTools.seedSampleProjects()
        let store = PatternStore.shared
        #expect(store.imported.count == SampleData.projects.count)
        #expect(store.project(id: "p1")?.title == "Marigold Cardigan")
    }

    @Test func seedSampleProjectsPopulatesCounterSnapshotForP1() {
        DevTools.seedSampleProjects()
        let defaults = SharedStore.defaults
        #expect(defaults.integer(forKey: SharedStore.Keys.rows("p1")) == 5)
        #expect(defaults.integer(forKey: SharedStore.Keys.stitches("p1")) == 34)
    }

    @Test func seedIsIdempotent() {
        DevTools.seedSampleProjects()
        DevTools.seedSampleProjects()
        #expect(PatternStore.shared.imported.count == SampleData.projects.count)
    }

    @Test func wipeAllDataClearsProjectsAndCounterKeys() {
        DevTools.seedSampleProjects()
        DevTools.wipeAllData()
        #expect(PatternStore.shared.imported.isEmpty)
        let defaults = SharedStore.defaults
        let lingering = defaults.dictionaryRepresentation().keys
            .filter { $0.hasPrefix("counter.") }
        #expect(lingering.isEmpty)
    }

    @Test func wipeAllDataPreservesKeychainAPIKey() {
        let stored = "sk-ant-test-token-DO-NOT-USE"
        Keychain.write(TestState.keychainAccount, value: stored)
        DevTools.wipeAllData()
        #expect(Keychain.read(TestState.keychainAccount) == stored)
        // Clean up so subsequent tests start fresh.
        Keychain.write(TestState.keychainAccount, value: nil)
    }
}
