import Foundation
@testable import WindyKnits

/// Cleans the UserDefaults / Keychain state that the app singletons read
/// from. Tests that mutate singleton storage call `wipeAll()` in their
/// initializer to start from a known-empty slate.
@MainActor
enum TestState {
    // Hardcoded copies of the private storage keys inside the source
    // files. If those keys ever change in the app, these mirror constants
    // must change too — the tests will otherwise silently no-op.
    static let patternImportedKey   = "patterns.imported.v1"
    static let cleanupSentinelKey   = "patterns.cleanupV2.done"
    static let consentKey           = "WindyKnits.cloudConsent.v1"
    static let userDisplayNameKey   = "WindyKnits.userDisplayName.v1"
    static let keychainAccount      = "WindyKnits.AnthropicAPIKey"
    static let appleUserIDAccount   = "WindyKnits.appleUserID"
    static let userEmailAccount     = "WindyKnits.userEmail"

    static func wipeAll() {
        let d = UserDefaults.standard
        for k in [patternImportedKey, cleanupSentinelKey, consentKey, userDisplayNameKey] {
            d.removeObject(forKey: k)
        }
        for account in [keychainAccount, appleUserIDAccount, userEmailAccount] {
            Keychain.write(account, value: nil)
        }
        wipeAppGroup()
        // Reset the live PatternStore singleton so the next test sees an
        // empty in-memory state, not whatever the previous test left.
        PatternStore.shared.resetAll()
        // The live WindyKnitsSettings singleton caches cloudConsent and
        // anthropicAPIKey in memory; mutating UserDefaults / Keychain above
        // doesn't propagate. Sync the in-memory copy so deleteAccount tests
        // can assert against `WindyKnitsSettings.shared.*` directly.
        WindyKnitsSettings.shared.cloudConsent = nil
        WindyKnitsSettings.shared.anthropicAPIKey = nil
    }

    static func wipeAppGroup() {
        SharedStore.wipeAllCounterKeys()
    }

    /// Loads the bundled sample projects into the shared store, mirroring the
    /// Debug "Load sample projects" button. Test target compiles with DEBUG
    /// defined so `DevTools` is always available here.
    static func seedSampleProjects() {
        DevTools.seedSampleProjects()
    }
}
