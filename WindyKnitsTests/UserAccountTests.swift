import Foundation
import Testing
@testable import WindyKnits

@MainActor
@Suite("UserAccount", .serialized)
struct UserAccountTests {

    init() { TestState.wipeAll() }

    @Test func freshInstanceHasNoIdentity() {
        let account = UserAccount()
        #expect(account.isSignedIn == false)
        #expect(account.appleUserID == nil)
        #expect(account.displayName == nil)
        #expect(account.email == nil)
    }

    @Test func adoptStoresAllThreeFields() {
        let account = UserAccount()
        account.adopt(.init(userID: "001234.abc",
                            displayName: "Windy",
                            email: "windy@example.com"))

        #expect(account.isSignedIn == true)
        #expect(account.appleUserID == "001234.abc")
        #expect(account.displayName == "Windy")
        #expect(account.email == "windy@example.com")
    }

    @Test func identityPersistsAcrossInstances() {
        let first = UserAccount()
        first.adopt(.init(userID: "001234.abc",
                          displayName: "Windy",
                          email: "windy@example.com"))

        let reloaded = UserAccount()
        #expect(reloaded.isSignedIn == true)
        #expect(reloaded.appleUserID == "001234.abc")
        #expect(reloaded.displayName == "Windy")
        #expect(reloaded.email == "windy@example.com")
    }

    @Test func signOutClearsEverything() {
        let account = UserAccount()
        account.adopt(.init(userID: "001234.abc",
                            displayName: "Windy",
                            email: "windy@example.com"))
        account.signOut()

        #expect(account.isSignedIn == false)
        #expect(account.appleUserID == nil)
        #expect(account.displayName == nil)
        #expect(account.email == nil)

        let reloaded = UserAccount()
        #expect(reloaded.isSignedIn == false)
        #expect(reloaded.appleUserID == nil)
        #expect(reloaded.displayName == nil)
        #expect(reloaded.email == nil)
    }

    /// Apple only returns the user's name and email on the **first** sign-in.
    /// Re-sign-in after revocation gives us just the user ID — we must keep
    /// the previously stored name/email rather than overwriting them with nil
    /// or the user would lose their identity on Keychain restore quirks.
    @Test func reSignInPreservesPreviouslyStoredNameAndEmail() {
        let account = UserAccount()
        account.adopt(.init(userID: "001234.abc",
                            displayName: "Windy",
                            email: "windy@example.com"))

        // Simulate Apple returning the same user ID but no name/email
        // (the post-revocation re-sign-in scenario).
        account.adopt(.init(userID: "001234.abc",
                            displayName: nil,
                            email: nil))

        #expect(account.displayName == "Windy")
        #expect(account.email == "windy@example.com")
    }

    // MARK: - needsNameEntry signal
    //
    // RootView observes this flag to auto-present NameEntrySheet right after
    // sign-in. It only fires when Apple withheld the name (the post-delete and
    // re-sign-in case the user hit on device), and must be cleared on success,
    // skip, or sign-out so it never leaks across identities.

    @Test func adoptFlipsNeedsNameEntryWhenAppleWithholdsName() {
        let account = UserAccount()

        account.adopt(.init(userID: "001234.abc", displayName: nil, email: nil))

        #expect(account.needsNameEntry == true)
    }

    @Test func adoptLeavesNeedsNameEntryOffWhenAppleDeliversName() {
        let account = UserAccount()

        account.adopt(.init(userID: "001234.abc", displayName: "Windy", email: nil))

        #expect(account.needsNameEntry == false)
    }

    /// Apple withholding the name on a re-sign-in is the common path (it's
    /// what happens after every sign-in after the first). When we have a
    /// previously-stored name from the original first sign-in, we should
    /// keep using it instead of nagging the user with the prompt.
    @Test func reSignInWithStoredNameDoesNotTriggerPrompt() {
        let first = UserAccount()
        first.adopt(.init(userID: "001234.abc", displayName: "Windy", email: nil))

        let second = UserAccount()
        second.adopt(.init(userID: "001234.abc", displayName: nil, email: nil))

        #expect(second.displayName == "Windy")
        #expect(second.needsNameEntry == false)
    }

    @Test func updateDisplayNameClearsNeedsNameEntry() {
        let account = UserAccount()
        account.adopt(.init(userID: "001234.abc", displayName: nil, email: nil))
        #expect(account.needsNameEntry == true)

        account.updateDisplayName("Windy")

        #expect(account.needsNameEntry == false)
    }

    @Test func emptyUpdateDisplayNameDoesNotClearNeedsNameEntry() {
        // The Skip button explicitly toggles `needsNameEntry` to false — we
        // shouldn't piggyback that on the empty-update path, since the
        // Settings field also passes empty strings through when the user
        // deliberately blanks their stored name.
        let account = UserAccount()
        account.adopt(.init(userID: "001234.abc", displayName: nil, email: nil))

        account.updateDisplayName("")

        #expect(account.needsNameEntry == true)
    }

    @Test func signOutClearsNeedsNameEntry() {
        let account = UserAccount()
        account.adopt(.init(userID: "001234.abc", displayName: nil, email: nil))
        #expect(account.needsNameEntry == true)

        account.signOut()

        #expect(account.needsNameEntry == false)
    }

    @Test func deleteAccountClearsNeedsNameEntry() async {
        let account = UserAccount()
        account.adopt(.init(userID: "001234.abc", displayName: nil, email: nil))
        #expect(account.needsNameEntry == true)

        await account.deleteAccount()

        #expect(account.needsNameEntry == false)
    }

    // MARK: - updateDisplayName
    //
    // Covers the Settings → Account inline name field, which exists because
    // Apple withholds `fullName` on re-sign-ins after the first one — so
    // re-signed users (including post-delete) need a way to set their own name.

    @Test func updateDisplayNameSetsAndPersists() {
        let account = UserAccount()
        account.adopt(.init(userID: "001234.abc", displayName: nil, email: nil))

        account.updateDisplayName("Windy")

        #expect(account.displayName == "Windy")
        let reloaded = UserAccount()
        #expect(reloaded.displayName == "Windy")
    }

    @Test func updateDisplayNameTrimsWhitespace() {
        let account = UserAccount()
        account.updateDisplayName("   Windy   ")

        #expect(account.displayName == "Windy")
    }

    @Test func updateDisplayNameWithEmptyClearsTheOverride() {
        let account = UserAccount()
        account.adopt(.init(userID: "001234.abc", displayName: "Windy", email: nil))
        #expect(account.displayName == "Windy")

        account.updateDisplayName("")

        #expect(account.displayName == nil)
        let reloaded = UserAccount()
        #expect(reloaded.displayName == nil)
    }

    @Test func updateDisplayNameWithWhitespaceOnlyClearsTheOverride() {
        let account = UserAccount()
        account.adopt(.init(userID: "001234.abc", displayName: "Windy", email: nil))

        account.updateDisplayName("   \n\t  ")

        #expect(account.displayName == nil)
    }

    @Test func emptyStringsAreTreatedAsNoData() {
        let account = UserAccount()
        account.adopt(.init(userID: "001234.abc",
                            displayName: "Windy",
                            email: "windy@example.com"))

        // Empty payload fields shouldn't clobber the existing values.
        account.adopt(.init(userID: "001234.abc",
                            displayName: "",
                            email: ""))

        #expect(account.displayName == "Windy")
        #expect(account.email == "windy@example.com")
    }

    // MARK: - deleteAccount
    //
    // Tests for the App Store 5.1.1(v) account-deletion path. Each test
    // exercises one storage layer in isolation so a regression points at the
    // layer that broke, not at the whole flow.

    @Test func deleteAccountClearsIdentity() async {
        let account = UserAccount()
        account.adopt(.init(userID: "001234.abc",
                            displayName: "Windy",
                            email: "windy@example.com"))

        await account.deleteAccount()

        #expect(account.isSignedIn == false)
        #expect(account.appleUserID == nil)
        #expect(account.displayName == nil)
        #expect(account.email == nil)

        let reloaded = UserAccount()
        #expect(reloaded.isSignedIn == false)
        #expect(reloaded.appleUserID == nil)
        #expect(reloaded.displayName == nil)
        #expect(reloaded.email == nil)
    }

    @Test func deleteAccountClearsImportedProjects() async {
        TestState.seedSampleProjects()
        #expect(!PatternStore.shared.imported.isEmpty)

        let account = UserAccount()
        account.adopt(.init(userID: "001234.abc", displayName: "Windy", email: nil))

        await account.deleteAccount()

        #expect(PatternStore.shared.imported.isEmpty)
    }

    @Test func deleteAccountClearsCounterKeys() async {
        TestState.seedSampleProjects()
        let suite = SharedStore.defaults
        let beforeCounterKeys = suite.dictionaryRepresentation().keys.filter {
            $0.hasPrefix("counter.")
        }
        #expect(!beforeCounterKeys.isEmpty)

        let account = UserAccount()
        account.adopt(.init(userID: "001234.abc", displayName: "Windy", email: nil))

        await account.deleteAccount()

        let afterCounterKeys = suite.dictionaryRepresentation().keys.filter {
            $0.hasPrefix("counter.")
        }
        #expect(afterCounterKeys.isEmpty)
    }

    /// Explicit counterpoint to `DevToolsTests.wipeAllDataPreservesKeychainAPIKey`
    /// — the Debug wipe preserves the API key (it's a user secret), but a
    /// full account deletion must remove it.
    @Test func deleteAccountClearsAnthropicAPIKey() async {
        WindyKnitsSettings.shared.anthropicAPIKey = "sk-ant-test"
        #expect(Keychain.read(TestState.keychainAccount) == "sk-ant-test")

        let account = UserAccount()
        account.adopt(.init(userID: "001234.abc", displayName: "Windy", email: nil))

        await account.deleteAccount()

        #expect(WindyKnitsSettings.shared.anthropicAPIKey == nil)
        #expect(Keychain.read(TestState.keychainAccount) == nil)
    }

    @Test func deleteAccountClearsCloudConsent() async {
        WindyKnitsSettings.shared.cloudConsent = true
        #expect(UserDefaults.standard.object(forKey: TestState.consentKey) as? Bool == true)

        let account = UserAccount()
        account.adopt(.init(userID: "001234.abc", displayName: "Windy", email: nil))

        await account.deleteAccount()

        #expect(WindyKnitsSettings.shared.cloudConsent == nil)
        #expect(UserDefaults.standard.object(forKey: TestState.consentKey) == nil)
    }

    /// The launch-migration sentinel must be reset so a reinstall after
    /// deletion re-runs `LaunchMigration.runIfNeeded()` and picks up any
    /// stragglers — otherwise a stale `true` would short-circuit the sweep.
    @Test func deleteAccountResetsCleanupSentinel() async {
        UserDefaults.standard.set(true, forKey: TestState.cleanupSentinelKey)
        #expect(UserDefaults.standard.bool(forKey: TestState.cleanupSentinelKey) == true)

        let account = UserAccount()
        account.adopt(.init(userID: "001234.abc", displayName: "Windy", email: nil))

        await account.deleteAccount()

        #expect(UserDefaults.standard.object(forKey: TestState.cleanupSentinelKey) == nil)
    }
}
