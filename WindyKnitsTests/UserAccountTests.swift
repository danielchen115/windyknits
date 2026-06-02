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
}
