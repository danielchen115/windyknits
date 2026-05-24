import Foundation
import Observation

/// Holds imported projects, persisted to UserDefaults so they survive relaunches.
/// Sample projects live separately in `SampleData` — `allProjects` interleaves
/// imported first (newest at top) followed by samples.
///
/// Status changes + deletions for sample projects can't mutate `SampleData`
/// directly (it's a read-only static), so we keep an override map for the
/// status and a deletion set, both persisted to UserDefaults so library
/// reorganisations survive a relaunch.
@Observable
final class PatternStore {
    static let shared = PatternStore()
    private static let storageKey         = "patterns.imported.v1"
    private static let statusOverrideKey  = "patterns.statusOverride.v1"
    private static let deletedKey         = "patterns.deleted.v1"

    private(set) var imported: [Project] = []
    private(set) var statusOverrides: [String: ProjectStatus] = [:]
    private(set) var deleted: Set<String> = []

    init() { load() }

    func add(_ project: Project) {
        imported.removeAll { $0.id == project.id }
        imported.insert(project, at: 0)
        deleted.remove(project.id)
        statusOverrides.removeValue(forKey: project.id)
        save()
    }

    /// Replaces an existing imported project in place, preserving its position
    /// in the list (unlike `add` which moves it to the top). Used by the
    /// project-edit screen and inline notes editing.
    func update(_ project: Project) {
        if let idx = imported.firstIndex(where: { $0.id == project.id }) {
            imported[idx] = project
        } else {
            imported.insert(project, at: 0)
        }
        save()
    }

    /// Returns the project as the user should see it — sample projects pick up
    /// their status override here so callers don't have to remember.
    func project(id: String) -> Project? {
        guard !deleted.contains(id) else { return nil }
        if var p = imported.first(where: { $0.id == id }) {
            if let s = statusOverrides[id] { p.status = s }
            return p
        }
        if var p = SampleData.projects.first(where: { $0.id == id }) {
            if let s = statusOverrides[id] { p.status = s }
            return p
        }
        return nil
    }

    /// Imported projects (newest first) followed by sample projects, filtered
    /// against the deletion set and with status overrides applied.
    func allProjects() -> [Project] {
        let combined = imported + SampleData.projects
        return combined.compactMap { p in
            guard !deleted.contains(p.id) else { return nil }
            var out = p
            if let s = statusOverrides[p.id] { out.status = s }
            return out
        }
    }

    func projects(in status: ProjectStatus) -> [Project] {
        allProjects().filter { $0.status == status }
    }

    func counts() -> [ProjectStatus: Int] {
        var m: [ProjectStatus: Int] = [.active: 0, .queue: 0, .finished: 0]
        for p in allProjects() { m[p.status, default: 0] += 1 }
        return m
    }

    /// Move a project to a different status. Mutates the imported record in
    /// place when the project came from there, otherwise records an override
    /// so sample data appears moved.
    func setStatus(_ id: String, to next: ProjectStatus) {
        if let idx = imported.firstIndex(where: { $0.id == id }) {
            imported[idx].status = next
            statusOverrides.removeValue(forKey: id)
        } else {
            statusOverrides[id] = next
        }
        save()
    }

    /// Remove a project. Imported projects are dropped from the array; sample
    /// projects go into the deletion set so they don't reappear next launch.
    func delete(_ id: String) {
        if imported.contains(where: { $0.id == id }) {
            imported.removeAll { $0.id == id }
        } else {
            deleted.insert(id)
        }
        statusOverrides.removeValue(forKey: id)
        save()
    }

    // MARK: - Persistence

    private func save() {
        let d = UserDefaults.standard
        if let data = try? JSONEncoder().encode(imported) {
            d.set(data, forKey: Self.storageKey)
        }
        let overrideRaw = statusOverrides.mapValues { $0.rawValue }
        if let data = try? JSONEncoder().encode(overrideRaw) {
            d.set(data, forKey: Self.statusOverrideKey)
        }
        if let data = try? JSONEncoder().encode(Array(deleted)) {
            d.set(data, forKey: Self.deletedKey)
        }
    }

    private func load() {
        let d = UserDefaults.standard
        if let data = d.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode([Project].self, from: data) {
            imported = decoded
        }
        if let data = d.data(forKey: Self.statusOverrideKey),
           let raw = try? JSONDecoder().decode([String: String].self, from: data) {
            statusOverrides = raw.compactMapValues { ProjectStatus(rawValue: $0) }
        }
        if let data = d.data(forKey: Self.deletedKey),
           let arr = try? JSONDecoder().decode([String].self, from: data) {
            deleted = Set(arr)
        }
    }
}
