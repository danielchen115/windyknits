import Foundation

/// State shared between the app and the Live Activity intent. Both targets are
/// in the `group.dc.knitting.shared` App Group, so reads/writes through `defaults`
/// are visible across the process boundary — important because the +1 button
/// on the Lock Screen runs `IncrementRowIntent` in the extension process,
/// which must mutate the same counter the app reads.
enum SharedStore {
    static let appGroup = "group.dc.knitting.shared"

    static let defaults: UserDefaults = {
        UserDefaults(suiteName: appGroup) ?? .standard
    }()

    enum Keys {
        static func rows(_ projectId: String)     -> String { "counter.\(projectId).rows" }
        static func stitches(_ projectId: String) -> String { "counter.\(projectId).stitches" }
        static func linked(_ projectId: String)   -> String { "counter.\(projectId).linked" }
        static func active(_ projectId: String)   -> String { "counter.\(projectId).active" }
        static func history(_ projectId: String)  -> String { "counter.\(projectId).history" }
        /// JSON dict `{"1": "K2…", "2": "Purl all", …}` mirrored by the app
        /// when a Live Activity session starts. The Live Activity intent
        /// reads this to surface the current row's instruction text without
        /// needing access to PatternStore.
        static func rowTexts(_ projectId: String) -> String { "counter.\(projectId).rowTexts" }
        /// Last project id opened in any counter — drives the Counter tab so
        /// it lands on the most recent counter instead of an empty state when
        /// the user has at least one project on the go.
        static let lastActiveProjectId = "counter.lastActiveProjectId"
    }

    /// Writes the per-row instruction text dictionary for `projectId` so the
    /// Live Activity (running in the widget extension) can look up the
    /// current row's text. Keys are stringified row numbers (1-based).
    static func setRowTexts(_ texts: [Int: String], projectId: String) {
        let stringKeyed = Dictionary(uniqueKeysWithValues:
            texts.map { (String($0.key), $0.value) })
        guard let data = try? JSONEncoder().encode(stringKeyed) else { return }
        defaults.set(data, forKey: Keys.rowTexts(projectId))
    }

    /// Returns the instruction text for `rowNumber` (1-based) of `projectId`,
    /// or nil if no pattern was seeded for this project.
    static func rowText(forRow rowNumber: Int, projectId: String) -> String? {
        guard rowNumber >= 1,
              let data = defaults.data(forKey: Keys.rowTexts(projectId)),
              let dict = try? JSONDecoder().decode([String: String].self, from: data)
        else { return nil }
        return dict[String(rowNumber)]
    }

    /// One-shot copy of any pre-existing `counter.*` keys out of
    /// `UserDefaults.standard` into the shared suite. Older builds wrote to
    /// `.standard`; without this, a user upgrading would see counters reset.
    static func migrateFromStandardIfNeeded() {
        let migratedKey = "counter.migratedToAppGroup.v1"
        guard !defaults.bool(forKey: migratedKey) else { return }
        let standard = UserDefaults.standard
        for (key, value) in standard.dictionaryRepresentation() where key.hasPrefix("counter.") {
            if defaults.object(forKey: key) == nil {
                defaults.set(value, forKey: key)
            }
        }
        defaults.set(true, forKey: migratedKey)
    }
}
