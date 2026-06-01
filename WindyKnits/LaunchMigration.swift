import ActivityKit
import Foundation

/// One-shot cleanup that runs on app launch to reconcile state left behind
/// by previous builds. Gated by the `patterns.cleanupV2.done` sentinel so it
/// only fires once per install.
///
/// Steps run in order — orphaned Live Activities first (so they don't
/// repopulate the counter keys we're about to sweep), then orphan key
/// removal, then legacy PatternStore key removal.
@MainActor
enum LaunchMigration {
    private static let sentinelKey = "patterns.cleanupV2.done"
    private static let counterKeyPrefix = "counter."

    static func runIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: sentinelKey) else { return }

        // Snapshot the project ids the store knows about. Lazily creates
        // PatternStore.shared (which loads from UserDefaults), so any
        // surviving imported projects are recognised here.
        let validIds = Set(PatternStore.shared.imported.map(\.id))

        Task { @MainActor in
            await endOrphanLiveActivities(validIds: validIds)
            sweepOrphanCounterKeys(validIds: validIds)
            dropLegacyPatternStoreKeys()
            UserDefaults.standard.set(true, forKey: sentinelKey)
        }
    }

    private static func endOrphanLiveActivities(validIds: Set<String>) async {
        for activity in Activity<CounterActivityAttributes>.activities
        where !validIds.contains(activity.attributes.projectId) {
            await activity.end(dismissalPolicy: .immediate)
        }
    }

    private static func sweepOrphanCounterKeys(validIds: Set<String>) {
        let defaults = SharedStore.defaults
        for (key, _) in defaults.dictionaryRepresentation() where key.hasPrefix(counterKeyPrefix) {
            // Skip the migration sentinel itself.
            guard key != "counter.migratedToAppGroup.v1" else { continue }
            // Keys look like `counter.<id>.<field>` — pluck the id out.
            let suffix = key.dropFirst(counterKeyPrefix.count)
            guard let dotIdx = suffix.firstIndex(of: ".") else { continue }
            let projectId = String(suffix[..<dotIdx])
            if !validIds.contains(projectId) {
                defaults.removeObject(forKey: key)
            }
        }
    }

    private static func dropLegacyPatternStoreKeys() {
        let d = UserDefaults.standard
        d.removeObject(forKey: "patterns.statusOverride.v1")
        d.removeObject(forKey: "patterns.deleted.v1")
    }
}
