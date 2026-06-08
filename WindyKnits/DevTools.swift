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
    /// screens look mid-flow without per-init branching in `CounterScreen`,
    /// and pins the Counter tab to p1 so the curated state is what the user
    /// sees on first open (otherwise `CounterTabRoot`'s "newest active" fallback
    /// would land on p3, which has no seeded counter state).
    static func seedSampleProjects() {
        let store = PatternStore.shared
        for project in SampleData.projects {
            store.add(project)
        }
        let defaults = SharedStore.defaults
        for (projectId, snapshot) in SampleData.initialCounterState {
            defaults.set(snapshot.rows,     forKey: SharedStore.Keys.rows(projectId))
            defaults.set(snapshot.stitches, forKey: SharedStore.Keys.stitches(projectId))
        }
        defaults.set("p1", forKey: SharedStore.Keys.lastActiveProjectId)
    }

    /// Removes every imported project and clears all counter / row-text /
    /// history state from the App Group. Leaves the Keychain alone — API
    /// keys are user secrets, not demo data. (Account deletion uses a
    /// different, fuller wipe; see `UserAccount.deleteAccount()`.)
    static func wipeAllData() {
        PatternStore.shared.resetAll()
        SharedStore.wipeAllCounterKeys()
    }
}
#endif
