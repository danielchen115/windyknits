import Foundation
import Observation

/// Holds imported projects, persisted to UserDefaults so they survive relaunches.
/// Sample projects live separately in `SampleData` — `allProjects` interleaves
/// imported first (newest at top) followed by samples.
@Observable
final class PatternStore {
    static let shared = PatternStore()
    private static let storageKey = "patterns.imported.v1"

    private(set) var imported: [Project] = []

    init() { load() }

    func add(_ project: Project) {
        imported.removeAll { $0.id == project.id }
        imported.insert(project, at: 0)
        save()
    }

    func project(id: String) -> Project? {
        if let p = imported.first(where: { $0.id == id }) { return p }
        return SampleData.projects.first(where: { $0.id == id })
    }

    func allProjects() -> [Project] {
        imported + SampleData.projects
    }

    // MARK: - Persistence

    private func save() {
        guard let data = try? JSONEncoder().encode(imported) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode([Project].self, from: data)
        else { return }
        imported = decoded
    }
}
