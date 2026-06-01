#if DEBUG
import Foundation

/// Developer-only helpers wired up from the Settings → Developer section.
/// Compiled out of Release builds so neither the seeder nor the data lives in
/// the App Store binary.
@MainActor
enum DevTools {
    /// Adds every project from `SampleData.projects` to the store as a real
    /// imported record. Idempotent — `PatternStore.add` dedupes by id, so
    /// tapping the button twice just refreshes any in-flight edits.
    ///
    /// Also seeds per-project counter snapshots into the App Group so demo
    /// screens look mid-flow without per-init branching in `CounterScreen`.
    static func seedSampleProjects() {
        let store = PatternStore.shared
        for project in SampleData.projects {
            store.add(project)
        }
        for (projectId, snapshot) in SampleData.initialCounterState {
            let defaults = SharedStore.defaults
            defaults.set(snapshot.rows,     forKey: SharedStore.Keys.rows(projectId))
            defaults.set(snapshot.stitches, forKey: SharedStore.Keys.stitches(projectId))
        }
    }

    /// Removes every imported project and clears all counter / row-text /
    /// history state from the App Group. Leaves the Keychain alone — API
    /// keys are user secrets, not demo data.
    static func wipeAllData() {
        PatternStore.shared.resetAll()
        let defaults = SharedStore.defaults
        for (key, _) in defaults.dictionaryRepresentation() where key.hasPrefix("counter.") {
            defaults.removeObject(forKey: key)
        }
        defaults.removeObject(forKey: "counter.migratedToAppGroup.v1")
    }
}
#endif
