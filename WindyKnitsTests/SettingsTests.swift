import Testing
import Foundation
@testable import WindyKnits

@MainActor
@Suite("WindyKnitsSettings", .serialized)
struct WindyKnitsSettingsTests {

    init() {
        TestState.wipeAll()
    }

    @Test func freshInstallHasNoConsentAndNoKey() {
        let s = WindyKnitsSettings()
        #expect(s.cloudConsent == nil)
        #expect(s.anthropicAPIKey == nil)
        #expect(s.canUseCloud == false)
    }

    @Test func canUseCloudRequiresBothConsentAndKey() {
        let s = WindyKnitsSettings()
        s.cloudConsent = true
        #expect(s.canUseCloud == false, "Consent alone is not enough")

        s.anthropicAPIKey = "sk-ant-fake"
        #expect(s.canUseCloud == true)

        s.cloudConsent = false
        #expect(s.canUseCloud == false, "Revoked consent disables cloud")

        s.cloudConsent = true
        s.anthropicAPIKey = ""
        #expect(s.canUseCloud == false, "Empty key counts as missing")
    }

    @Test func resetCloudConsentClearsTheStoredFlag() {
        let s = WindyKnitsSettings()
        s.cloudConsent = true
        #expect(UserDefaults.standard.object(forKey: TestState.consentKey) != nil)
        s.resetCloudConsent()
        #expect(s.cloudConsent == nil)
        #expect(UserDefaults.standard.object(forKey: TestState.consentKey) == nil)
    }

    @Test func consentSurvivesARelaunch() {
        let first = WindyKnitsSettings()
        first.cloudConsent = true

        let second = WindyKnitsSettings()
        #expect(second.cloudConsent == true)
    }

    @Test func apiKeySurvivesARelaunch() {
        let first = WindyKnitsSettings()
        first.anthropicAPIKey = "sk-ant-roundtrip"

        let second = WindyKnitsSettings()
        #expect(second.anthropicAPIKey == "sk-ant-roundtrip")
    }
}

@MainActor
@Suite("Keychain wrapper", .serialized)
struct KeychainTests {

    private let testAccount = "WindyKnits.test.key"

    init() {
        Keychain.write(testAccount, value: nil)
    }

    @Test func readReturnsNilForMissingAccount() {
        #expect(Keychain.read(testAccount) == nil)
    }

    @Test func writeThenReadRoundTrips() {
        Keychain.write(testAccount, value: "topsecret")
        #expect(Keychain.read(testAccount) == "topsecret")
        Keychain.write(testAccount, value: nil)
    }

    @Test func writeOverwritesPreviousValue() {
        Keychain.write(testAccount, value: "old")
        Keychain.write(testAccount, value: "new")
        #expect(Keychain.read(testAccount) == "new")
        Keychain.write(testAccount, value: nil)
    }

    @Test func writeNilDeletesEntry() {
        Keychain.write(testAccount, value: "transient")
        Keychain.write(testAccount, value: nil)
        #expect(Keychain.read(testAccount) == nil)
    }

    @Test func writeEmptyStringDeletesEntry() {
        Keychain.write(testAccount, value: "value")
        Keychain.write(testAccount, value: "")
        #expect(Keychain.read(testAccount) == nil)
    }
}
