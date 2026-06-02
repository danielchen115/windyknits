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
    }

    /// Clear all identity state. The root-view gate flips to the welcome
    /// screen on the next render because `isSignedIn` becomes false.
    func signOut() {
        appleUserID = nil
        displayName = nil
        email = nil
        Keychain.write(Self.appleUserIDAccount, value: nil)
        Keychain.write(Self.emailAccount, value: nil)
        defaults.removeObject(forKey: Self.displayNameKey)
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
