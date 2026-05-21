import ActivityKit
import AppIntents
import Foundation

// MARK: - Shared helper

/// All three intents conform to `LiveActivityIntent` so iOS runs `perform()`
/// in the app's process (waking it in the background if needed). A plain
/// `AppIntent` would run in the widget extension when the app isn't already
/// foregrounded, and `Activity.activities` in that extension doesn't see
/// activities owned by the app — `activity.update(...)` would silently no-op
/// and the Lock Screen number would never refresh.

enum CounterMutation {
    /// Writes `newRows` to the shared counter store, looks up the new
    /// current-row instruction text, and pushes a fresh ContentState into
    /// every matching active Live Activity. Used by all three button intents.
    static func apply(newRows: Int, projectId: String) async {
        SharedStore.defaults.set(newRows, forKey: SharedStore.Keys.rows(projectId))

        let nextRowText = SharedStore.rowText(forRow: newRows + 1, projectId: projectId)
        let state = CounterActivityAttributes.ContentState(
            rows: newRows, currentRowText: nextRowText)

        for activity in Activity<CounterActivityAttributes>.activities
        where activity.attributes.projectId == projectId {
            await activity.update(
                ActivityContent(state: state, staleDate: nil))
        }
    }

    /// Appends a single completed-row entry to the shared history, capped at
    /// 50 entries to match the in-app behavior. Only called on increment —
    /// decrement and reset don't add history (reset clears it).
    static func appendHistory(rowNumber: Int, projectId: String) {
        struct Entry: Codable { let n: Int; let timestamp: Date; let sts: Int }
        let key = SharedStore.Keys.history(projectId)
        let existing = SharedStore.defaults.string(forKey: key) ?? "[]"
        var list: [Entry] = []
        if let data = existing.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([Entry].self, from: data) {
            list = decoded
        }
        list.append(.init(n: rowNumber, timestamp: Date(), sts: 0))
        if list.count > 50 { list = Array(list.suffix(50)) }
        if let data = try? JSONEncoder().encode(list),
           let str = String(data: data, encoding: .utf8) {
            SharedStore.defaults.set(str, forKey: key)
        }
    }
}

// MARK: - Intents

struct IncrementRowIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Add a row"
    static var description = IntentDescription(
        "Marks one more row done on your active WindyKnits project.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Project ID")
    var projectId: String?

    init() {}
    init(projectId: String?) { self.projectId = projectId }

    func perform() async throws -> some IntentResult {
        let id = projectId ?? "p1"
        let current = SharedStore.defaults.integer(forKey: SharedStore.Keys.rows(id))
        let next = current + 1
        CounterMutation.appendHistory(rowNumber: next, projectId: id)
        await CounterMutation.apply(newRows: next, projectId: id)
        return .result()
    }
}

struct DecrementRowIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Undo a row"
    static var description = IntentDescription(
        "Decreases the row counter by one. Clamped at zero.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Project ID")
    var projectId: String?

    init() {}
    init(projectId: String?) { self.projectId = projectId }

    func perform() async throws -> some IntentResult {
        let id = projectId ?? "p1"
        let current = SharedStore.defaults.integer(forKey: SharedStore.Keys.rows(id))
        let next = max(0, current - 1)
        await CounterMutation.apply(newRows: next, projectId: id)
        return .result()
    }
}

struct ResetRowsIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Reset rows"
    static var description = IntentDescription(
        "Resets the row counter to zero and clears completion history.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Project ID")
    var projectId: String?

    init() {}
    init(projectId: String?) { self.projectId = projectId }

    func perform() async throws -> some IntentResult {
        let id = projectId ?? "p1"
        SharedStore.defaults.set("[]", forKey: SharedStore.Keys.history(id))
        await CounterMutation.apply(newRows: 0, projectId: id)
        return .result()
    }
}
