import Foundation
import Observation
import Security

/// User-facing settings. Backs the import screen, the consent sheet, and the
/// dedicated Settings screen. Persists `cloudConsent` to UserDefaults and the
/// Anthropic API key to Keychain.
@Observable
final class WindyKnitsSettings {
    static let shared = WindyKnitsSettings()

    private static let consentKey = "WindyKnits.cloudConsent.v1"
    private static let keychainAccount = "WindyKnits.AnthropicAPIKey"

    /// nil = user has not yet been asked.
    var cloudConsent: Bool? {
        didSet { persistConsent() }
    }

    var anthropicAPIKey: String? {
        didSet { Keychain.write(Self.keychainAccount, value: anthropicAPIKey) }
    }

    init() {
        // Load — these assignments fire didSet once with the loaded value,
        // which writes the same value back. Idempotent, only happens at boot.
        cloudConsent = UserDefaults.standard.object(forKey: Self.consentKey) as? Bool
        anthropicAPIKey = Keychain.read(Self.keychainAccount)
    }

    /// True when the user has explicitly opted into cloud parsing AND we have
    /// an API key to send. The import pipeline gates Tier 2 on this.
    var canUseCloud: Bool {
        cloudConsent == true && (anthropicAPIKey ?? "").isEmpty == false
    }

    /// Forgets the prior consent decision so the sheet appears again next time.
    func resetCloudConsent() {
        cloudConsent = nil
    }

    private func persistConsent() {
        if let value = cloudConsent {
            UserDefaults.standard.set(value, forKey: Self.consentKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.consentKey)
        }
    }
}

// MARK: - Keychain

/// Thin wrapper around `SecItem` for storing single string secrets keyed by
/// account name. Errors are swallowed — secret storage is best-effort here.
enum Keychain {
    static func read(_ account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let s = String(data: data, encoding: .utf8) else { return nil }
        return s
    }

    static func write(_ account: String, value: String?) {
        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(baseQuery as CFDictionary)

        guard let value, !value.isEmpty,
              let data = value.data(using: .utf8) else { return }
        var add = baseQuery
        add[kSecValueData as String] = data
        SecItemAdd(add as CFDictionary, nil)
    }
}
