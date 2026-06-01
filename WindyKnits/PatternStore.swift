import Foundation
import Observation

/// Holds imported projects, persisted to a UserDefaults suite so they survive
/// relaunches. The shared instance is backed by `UserDefaults.standard`;
/// tests can construct isolated instances against a dedicated suite to avoid
/// stepping on each other.
@Observable
final class PatternStore {
    static let shared = PatternStore(defaults: .standard)
    private static let storageKey = "patterns.imported.v1"

    private(set) var imported: [Project] = []
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    func add(_ project: Project) {
        imported.removeAll { $0.id == project.id }
        imported.insert(project, at: 0)
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

    func project(id: String) -> Project? {
        imported.first(where: { $0.id == id })
    }

    func allProjects() -> [Project] { imported }

    func projects(in status: ProjectStatus) -> [Project] {
        imported.filter { $0.status == status }
    }

    func counts() -> [ProjectStatus: Int] {
        var m: [ProjectStatus: Int] = [.active: 0, .queue: 0, .finished: 0]
        for p in imported { m[p.status, default: 0] += 1 }
        return m
    }

    func setStatus(_ id: String, to next: ProjectStatus) {
        guard let idx = imported.firstIndex(where: { $0.id == id }) else { return }
        imported[idx].status = next
        save()
    }

    func delete(_ id: String) {
        imported.removeAll { $0.id == id }
        save()
    }

    /// Wipes the in-memory + persisted state. DevTools calls this from the
    /// Debug "Wipe all data" button; tests call it as part of `TestState`.
    func resetAll() {
        imported = []
        save()
    }

    // MARK: - Persistence

    private func save() {
        if let data = try? JSONEncoder().encode(imported) {
            defaults.set(data, forKey: Self.storageKey)
        }
    }

    private func load() {
        if let data = defaults.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode([Project].self, from: data) {
            imported = decoded
        }
    }
}
