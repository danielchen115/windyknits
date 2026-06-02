import Testing
import Foundation
@testable import WindyKnits

@MainActor
@Suite("FeatureFlags")
struct FeatureFlagsTests {

    /// Each test gets its own UserDefaults suite so concurrent tests can't
    /// step on each other.
    private let defaults: UserDefaults

    init() {
        let suiteName = "FeatureFlagsTests-\(UUID().uuidString)"
        guard let d = UserDefaults(suiteName: suiteName) else {
            fatalError("Failed to create UserDefaults suite for test isolation")
        }
        for (key, _) in d.dictionaryRepresentation() {
            d.removeObject(forKey: key)
        }
        self.defaults = d
    }

    #if DEBUG
    @Test func defaultsToTrueInDebugWhenNoPriorValue() {
        let flags = FeatureFlags(defaults: defaults)
        #expect(flags.pdfImportEnabled == true)
    }

    @Test func setterPersistsAcrossInstances() {
        let flags = FeatureFlags(defaults: defaults)
        flags.setPdfImportEnabled(false)

        let reloaded = FeatureFlags(defaults: defaults)
        #expect(reloaded.pdfImportEnabled == false)
    }

    @Test func setterUpdatesObservablePropertyInPlace() {
        let flags = FeatureFlags(defaults: defaults)
        #expect(flags.pdfImportEnabled == true)
        flags.setPdfImportEnabled(false)
        #expect(flags.pdfImportEnabled == false)
        flags.setPdfImportEnabled(true)
        #expect(flags.pdfImportEnabled == true)
    }

    @Test func explicitFalseSurvivesReinitialization() {
        defaults.set(false, forKey: "feature.pdfImport")
        let flags = FeatureFlags(defaults: defaults)
        #expect(flags.pdfImportEnabled == false)
    }
    #endif
}
