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
    @Environment(UserAccount.self) private var account
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
        @Bindable var bindableAccount = account

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
                CounterTabRoot(switchTab: { tab = $0 })
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
        // Auto-prompts for a name once after sign-in when SIWA didn't deliver
        // one. Lives at the RootView level so it surfaces immediately over
        // whatever tab loads first; binding goes back to false on any
        // dismissal (Save, Skip, or swipe-down).
        .sheet(isPresented: $bindableAccount.needsNameEntry) {
            NameEntrySheet()
        }
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

/// Counter tab landing view. Resumes on whichever project was last open in a
/// counter; falls back to an empty-state CTA when no valid project remains.
struct CounterTabRoot: View {
    var switchTab: (AppTab) -> Void
    @Environment(PatternStore.self) private var store
    @AppStorage(SharedStore.Keys.lastActiveProjectId, store: SharedStore.defaults)
    private var lastProjectId: String = ""

    var body: some View {
        if !lastProjectId.isEmpty, store.project(id: lastProjectId) != nil {
            CounterScreen(projectId: lastProjectId, showsBackButton: false)
        } else if let firstActive = store.projects(in: .active).first {
            // No remembered project but the user has at least one — land on
            // the newest active so the tab is immediately useful.
            CounterScreen(projectId: firstActive.id, showsBackButton: false)
        } else {
            CounterTabEmptyState(switchTab: switchTab)
        }
    }
}

private struct CounterTabEmptyState: View {
    var switchTab: (AppTab) -> Void

    var body: some View {
        ZStack {
            Palette.cream.ignoresSafeArea()
            VStack(spacing: 16) {
                Spacer(minLength: 60)
                Image(systemName: "number.square")
                    .font(.system(size: 32, weight: .regular))
                    .foregroundStyle(Palette.primaryDark)
                    .frame(width: 80, height: 80)
                    .background(RoundedRectangle(cornerRadius: 22).fill(Palette.creamWarm))
                VStack(spacing: 6) {
                    Text("No counter yet.")
                        .font(AppFont.serif(22))
                        .foregroundStyle(Palette.walnut)
                    Text("Pick a project from your library to start counting rows here.")
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.walnutMute)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .frame(maxWidth: 280)
                }
                Button { switchTab(.projects) } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "books.vertical")
                        Text("Go to Library")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Palette.primary))
                }
                .buttonStyle(PressScaleStyle())
                .padding(.top, 4)
                Spacer()
            }
            .padding(.horizontal, 24)
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview {
    RootView().environment(PatternStore.shared)
}
