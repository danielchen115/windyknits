import Foundation

/// Outward-facing URLs the app links to. Centralised so the Settings "About"
/// section, App Store metadata, and any future surfaces (welcome screens,
/// onboarding) share one source of truth.
enum AppLinks {
    /// Hosted privacy policy. Swap in the production URL before submission.
    // TODO: replace with hosted privacy policy URL before App Store submission.
    static let privacyPolicy = URL(string: "https://example.com/windyknits-privacy")!

    /// Short attribution line shown in Settings → About. Plain text — keep
    /// in sync with the parsing tiers in `PatternLLMRefiner`.
    static let acknowledgments =
        "Pattern parsing uses Apple Intelligence on supported devices and Anthropic Claude as an opt-in fallback. Knit on."
}

/// Human-readable build metadata read straight out of `Info.plist`. Used by
/// Settings → About; safe to call from any thread.
enum AppVersion {
    static var marketing: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }
    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
    }
    /// "1.0 (1)" — what most apps surface in About sections.
    static var formatted: String { "\(marketing) (\(build))" }
}
