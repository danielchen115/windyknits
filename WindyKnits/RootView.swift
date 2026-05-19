import SwiftUI

enum AppTab: Hashable { case today, projects, counter, you }

enum Route: Hashable {
    case project(String)
    case pattern(String)
    case counter(String)
    case importPDF
}

struct RootView: View {
    @State private var tab: AppTab = .today
    @State private var todayPath = NavigationPath()
    @State private var projectsPath = NavigationPath()
    @State private var counterPath = NavigationPath()
    @State private var youPath = NavigationPath()

    var body: some View {
        TabView(selection: $tab) {
            NavigationStack(path: $todayPath) {
                TodayScreen(path: $todayPath, switchTab: { tab = $0 })
                    .navigationDestinationForRoutes()
            }
            .tabItem { Label("Today", systemImage: "house.fill") }
            .tag(AppTab.today)

            NavigationStack(path: $projectsPath) {
                LibraryScreen()
                    .navigationDestinationForRoutes()
            }
            .tabItem { Label("Projects", systemImage: "books.vertical.fill") }
            .tag(AppTab.projects)

            NavigationStack(path: $counterPath) {
                CounterScreen(projectId: "p1", showsBackButton: false)
                    .navigationDestinationForRoutes()
            }
            .tabItem { Label("Counter", systemImage: "number.square.fill") }
            .tag(AppTab.counter)

            NavigationStack(path: $youPath) {
                YouScreen()
                    .navigationDestinationForRoutes()
            }
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
            }
        }
    }
}

#Preview { RootView() }
