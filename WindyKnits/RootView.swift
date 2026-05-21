import SwiftUI

enum AppTab: Hashable { case today, projects, counter, you }

enum Route: Hashable {
    case project(String)
    case pattern(String)
    case counter(String)
    case importPDF
    case manualPattern
    case editProject(String)
    case settings
}

/// Per-tab navigation path holder. Descendants can read this via
/// `@Environment(NavCoordinator.self)` to mutate the stack — e.g. to swap the
/// manual-pattern flow out for a project-detail screen after saving.
@Observable
final class NavCoordinator {
    var path = NavigationPath()

    func push(_ route: Route) { path.append(route) }

    /// Pops all pushed screens and lands on `route`. Used by the manual-pattern
    /// Saved screen to return the user to the project they just created
    /// without leaving the Import/Manual screens stacked underneath.
    func resetTo(_ route: Route) {
        path = NavigationPath()
        path.append(route)
    }
}

struct RootView: View {
    @State private var tab: AppTab = .today
    @State private var todayNav    = NavCoordinator()
    @State private var projectsNav = NavCoordinator()
    @State private var counterNav  = NavCoordinator()
    @State private var youNav      = NavCoordinator()

    var body: some View {
        @Bindable var today    = todayNav
        @Bindable var projects = projectsNav
        @Bindable var counter  = counterNav
        @Bindable var you      = youNav

        TabView(selection: $tab) {
            NavigationStack(path: $today.path) {
                TodayScreen(path: $today.path, switchTab: { tab = $0 })
                    .navigationDestinationForRoutes()
            }
            .environment(todayNav)
            .tabItem { Label("Today", systemImage: "house.fill") }
            .tag(AppTab.today)

            NavigationStack(path: $projects.path) {
                LibraryScreen()
                    .navigationDestinationForRoutes()
            }
            .environment(projectsNav)
            .tabItem { Label("Projects", systemImage: "books.vertical.fill") }
            .tag(AppTab.projects)

            NavigationStack(path: $counter.path) {
                CounterScreen(projectId: "p1", showsBackButton: false)
                    .navigationDestinationForRoutes()
            }
            .environment(counterNav)
            .tabItem { Label("Counter", systemImage: "number.square.fill") }
            .tag(AppTab.counter)

            NavigationStack(path: $you.path) {
                YouScreen()
                    .navigationDestinationForRoutes()
            }
            .environment(youNav)
            .tabItem { Label("You", systemImage: "person.crop.circle.fill") }
            .tag(AppTab.you)
        }
        .tint(Palette.primary)
    }
}

extension View {
    @ViewBuilder
    func navigationDestinationForRoutes() -> some View {
        self.navigationDestination(for: Route.self) { route in
            switch route {
            case .project(let id):  ProjectDetailScreen(projectId: id)
            case .pattern(let id):  PatternViewerScreen(projectId: id)
            case .counter(let id):  CounterScreen(projectId: id)
            case .importPDF:        ImportScreen()
            case .manualPattern:    ManualPatternScreen()
            case .editProject(let id): ProjectEditScreen(projectId: id)
            case .settings:         SettingsScreen()
            }
        }
    }
}

#Preview {
    RootView().environment(PatternStore.shared)
}
