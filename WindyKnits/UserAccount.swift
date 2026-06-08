import ActivityKit
import AuthenticationServices
import Foundation
import Observation

/// SIWA-derived user identity. Owns the Apple user ID, display name, and
/// email returned by Sign in with Apple, persisting each to the storage
/// best suited to it:
///
/// * `appleUserID` and `email` in Keychain so they survive reinstall when
///   iCloud Keychain is on — `appleUserID` is the load-bearing field for
///   credential-state revocation checks at launch.
/// * `displayName` in UserDefaults; not sensitive, and Apple only returns
///   the user's name on the **first** sign-in, so we have to persist it
///   eagerly. A revoked-then-re-signed-in user comes back with `nil` name
///   and `nil` email from Apple — `adopt(_:)` deliberately keeps the
///   previously stored values in that case rather than clobbering them.
///
/// The app gates its root view on `isSignedIn`; the welcome screen is
/// shown until a SIWA credential has been adopted. This keeps
/// `displayName` non-nil everywhere downstream.
@Observable
final class UserAccount {
    static let shared = UserAccount()

    private let defaults: UserDefaults

    // Storage keys are mirrored in WindyKnitsTests/TestSupport.swift —
    // tests silently no-op if the mirror gets out of sync, so update both.
    private static let displayNameKey      = "WindyKnits.userDisplayName.v1"
    private static let appleUserIDAccount  = "WindyKnits.appleUserID"
    private static let emailAccount        = "WindyKnits.userEmail"

    private(set) var appleUserID: String?
    private(set) var displayName: String?
    private(set) var email: String?

    /// Transient — set true by `adopt(_:)` when the just-signed-in user has
    /// no usable display name, so the UI can present a one-shot name-entry
    /// sheet. Cleared on dismissal, on successful `updateDisplayName`, and
    /// on `signOut` so it never leaks across identities. Deliberately not
    /// persisted: a force-quit during the prompt means we don't nag the user
    /// on every launch — they can always set the name in Settings later.
    var needsNameEntry: Bool = false

    var isSignedIn: Bool { appleUserID != nil }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.appleUserID = Keychain.read(Self.appleUserIDAccount)
        self.displayName = defaults.string(forKey: Self.displayNameKey)
        self.email = Keychain.read(Self.emailAccount)
    }

    /// Storage-friendly value type. Production code constructs this from an
    /// `ASAuthorizationAppleIDCredential` at the call site; tests
    /// instantiate it directly because the credential's initializer is
    /// private.
    struct SignInPayload: Sendable, Equatable {
        let userID: String
        let displayName: String?
        let email: String?
    }

    /// Persist a fresh SIWA payload. The first sign-in is the only time
    /// Apple returns name/email — on re-sign-ins (post-revocation) those
    /// fields arrive nil and we deliberately keep the previously stored
    /// values so the user doesn't end up nameless.
    func adopt(_ payload: SignInPayload) {
        appleUserID = payload.userID
        Keychain.write(Self.appleUserIDAccount, value: payload.userID)

        if let name = payload.displayName, !name.isEmpty {
            displayName = name
            defaults.set(name, forKey: Self.displayNameKey)
        }

        if let newEmail = payload.email, !newEmail.isEmpty {
            email = newEmail
            Keychain.write(Self.emailAccount, value: newEmail)
        }

        // After the dust settles, do we still lack a name? Apple withholds
        // `fullName` on every sign-in after the first one for a given Apple
        // ID + app pair, so a re-signed (or post-delete-account) user lands
        // here with `displayName` nil. Signal the UI to prompt once.
        needsNameEntry = (displayName ?? "").isEmpty
    }

    /// Replace the locally-cached display name from user input — typically
    /// the inline-editable field in Settings → Account. Needed because Apple
    /// only delivers the SIWA `fullName` on the **very first** sign-in for an
    /// Apple ID + app pair; any re-sign-in (including after `deleteAccount`)
    /// returns nil, leaving us with no name to greet the user with. Empty or
    /// whitespace-only input clears the override entirely.
    func updateDisplayName(_ newValue: String) {
        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            displayName = nil
            defaults.removeObject(forKey: Self.displayNameKey)
        } else {
            displayName = trimmed
            defaults.set(trimmed, forKey: Self.displayNameKey)
            needsNameEntry = false
        }
    }

    /// Clear all identity state. The root-view gate flips to the welcome
    /// screen on the next render because `isSignedIn` becomes false.
    func signOut() {
        appleUserID = nil
        displayName = nil
        email = nil
        needsNameEntry = false
        Keychain.write(Self.appleUserIDAccount, value: nil)
        Keychain.write(Self.emailAccount, value: nil)
        defaults.removeObject(forKey: Self.displayNameKey)
    }

    /// Permanently delete the account and every piece of on-device data
    /// tied to it — required by App Store Review Guideline 5.1.1(v).
    ///
    /// Order matters: end Live Activities first so the widget extension
    /// can't repopulate counter keys mid-wipe; clear identity last so the
    /// root-view gate's flip to `WelcomeView` is what signals completion
    /// to the user (no toast or confirmation screen — just teleport home).
    ///
    /// We deliberately do not call Apple's REST `/auth/revoke` endpoint —
    /// that requires a server with the team's private signing key, which
    /// a client-only app doesn't have. The confirmation copy in
    /// `SettingsScreen` points the user at iOS Settings → Apple ID → Sign
    /// in with Apple if they also want to revoke the server-side record.
    ///
    /// Note: Live Activity termination can't be unit-tested — it needs
    /// the ActivityKit host process — so step 1 is verified manually.
    @MainActor
    func deleteAccount() async {
        for activity in Activity<CounterActivityAttributes>.activities {
            await activity.end(dismissalPolicy: .immediate)
        }
        PatternStore.shared.resetAll()
        SharedStore.wipeAllCounterKeys()
        WindyKnitsSettings.shared.anthropicAPIKey = nil
        WindyKnitsSettings.shared.cloudConsent = nil
        defaults.removeObject(forKey: "patterns.cleanupV2.done")
        signOut()
    }

    /// Re-validate the stored Apple user ID against Apple's servers. Runs
    /// at launch and on scene activation so the user is signed out if
    /// they revoked the credential from iOS Settings → Apple ID → Sign in
    /// with Apple → WindyKnits → Stop Using.
    ///
    /// Transient failures (offline, etc.) are intentionally swallowed —
    /// we'd rather leave the user signed in across a flaky launch than
    /// kick them out on a network blip.
    @MainActor
    func refreshCredentialState() async {
        guard let userID = appleUserID else { return }
        let provider = ASAuthorizationAppleIDProvider()
        do {
            let state = try await provider.credentialState(forUserID: userID)
            switch state {
            case .authorized:
                return
            case .revoked, .notFound, .transferred:
                signOut()
            @unknown default:
                return
            }
        } catch {
            return
        }
    }
}

extension UserAccount.SignInPayload {
    /// Map an Apple credential into the storage-friendly value type.
    /// Prefers `givenName` ("Hello, Daniel" reads better than "Hello,
    /// Daniel Chen"); falls back to the locale-formatted full name when
    /// no given name is present.
    init(credential: ASAuthorizationAppleIDCredential) {
        self.userID = credential.user
        if let components = credential.fullName {
            let given = components.givenName?.trimmingCharacters(in: .whitespaces) ?? ""
            if !given.isEmpty {
                self.displayName = given
            } else {
                let formatted = components.formatted().trimmingCharacters(in: .whitespaces)
                self.displayName = formatted.isEmpty ? nil : formatted
            }
        } else {
            self.displayName = nil
        }
        self.email = credential.email
    }
}
