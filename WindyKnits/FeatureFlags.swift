import Foundation
import Observation

/// Single source of truth for in-app feature flags. Inject via
/// `.environment(FeatureFlags.shared)` in `WindyKnitsApp`; consumers read with
/// `@Environment(FeatureFlags.self) private var flags`. Mutations via the
/// Debug-only setters propagate immediately because the class is `@Observable`.
///
/// Each flag's Release behaviour is hard-coded in `init` so a stale
/// UserDefaults value from a previous Debug install can't accidentally enable
/// a feature in a shipped build.
@Observable
final class FeatureFlags {
    static let shared = FeatureFlags(defaults: .standard)

    private let defaults: UserDefaults

    /// Show PDF-import entry points across the app. Off in Release until the
    /// parser is trustworthy; defaults on in Debug so dev/QA can exercise the
    /// flow. Toggle via Settings → Developer.
    private(set) var pdfImportEnabled: Bool

    init(defaults: UserDefaults) {
        self.defaults = defaults
        #if DEBUG
        if defaults.object(forKey: Self.pdfImportKey) != nil {
            self.pdfImportEnabled = defaults.bool(forKey: Self.pdfImportKey)
        } else {
            self.pdfImportEnabled = true
        }
        #else
        // Hard-coded — UserDefaults is never read in Release, so a flag value
        // persisted by a prior Debug install can't leak into a shipped binary.
        self.pdfImportEnabled = false
        #endif
    }

    private static let pdfImportKey = "feature.pdfImport"

    #if DEBUG
    func setPdfImportEnabled(_ value: Bool) {
        defaults.set(value, forKey: Self.pdfImportKey)
        pdfImportEnabled = value
    }
    #endif
}
