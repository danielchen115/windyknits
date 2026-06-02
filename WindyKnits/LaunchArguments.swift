#if DEBUG
import Foundation

/// Translates UI-test launch arguments into in-app state. Called once from
/// `WindyKnitsApp.init` so that tests can declare the starting state
/// declaratively via `XCUIApplication.launchArguments` without needing a
/// separate test bundle ID or app group.
///
/// Debug-only — the entire file compiles out of Release, so a shipped binary
/// cannot be put into a test state through command-line arguments.
@MainActor
enum LaunchArguments {
    /// Reset PatternStore + every `counter.*` key in the App Group, leaving
    /// the Keychain intact. Mirrors the Settings → Developer "Wipe all data"
    /// button.
    static let reset = "--ui-test-reset"

    /// Seed `SampleData.projects` into the store as real imported entries
    /// and populate the curated counter snapshot for p1. Mirrors "Load
    /// sample projects".
    static let seedSamples = "--ui-test-seed-samples"

    /// Force the PDF-import feature flag off (hides import entry points).
    static let pdfImportOff = "--ui-test-pdf-import-off"

    /// Force the PDF-import feature flag on (shows import entry points).
    static let pdfImportOn = "--ui-test-pdf-import-on"

    /// Inject a stub Sign in with Apple identity so the root view skips
    /// the welcome screen and renders the tab bar. UI tests that aren't
    /// specifically exercising the SIWA flow should pass this so the rest
    /// of the app is reachable. `UITestApp.launch(...)` adds it by default.
    static let skipSignIn = "--ui-test-skip-signin"

    static func applyIfNeeded() {
        let args = CommandLine.arguments
        // Reset must run before any seeding, otherwise the seeded projects
        // would be wiped out immediately.
        if args.contains(reset) {
            DevTools.wipeAllData()
        }
        if args.contains(seedSamples) {
            DevTools.seedSampleProjects()
        }
        if args.contains(pdfImportOff) {
            FeatureFlags.shared.setPdfImportEnabled(false)
        }
        if args.contains(pdfImportOn) {
            FeatureFlags.shared.setPdfImportEnabled(true)
        }
        if args.contains(skipSignIn) {
            UserAccount.shared.adopt(.init(userID: "ui-test-user",
                                           displayName: "Test User",
                                           email: nil))
        }
    }
}
#endif
