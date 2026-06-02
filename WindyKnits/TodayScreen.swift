import SwiftUI

struct TodayScreen: View {
    @Binding var path: NavigationPath
    var switchTab: (AppTab) -> Void = { _ in }
    @Environment(PatternStore.self) private var store
    @Environment(FeatureFlags.self) private var flags
    @Environment(UserAccount.self) private var account

    init(path: Binding<NavigationPath> = .constant(NavigationPath()),
         switchTab: @escaping (AppTab) -> Void = { _ in }) {
        self._path = path
        self.switchTab = switchTab
    }

    private var todayLabel: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f.string(from: Date())
    }

    /// First active project (newest first). Drives the "currently knitting"
    /// card; when nil the card is replaced with a Start CTA.
    private var active: Project? { store.projects(in: .active).first }

    /// Other active projects shown under "On the needles".
    private var otherActive: [Project] {
        guard let active else { return store.projects(in: .active) }
        return store.projects(in: .active).filter { $0.id != active.id }
    }

    var body: some View {
        ZStack {
            Palette.cream.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    greeting
                    if let active {
                        ActiveProjectCard(project: active, path: $path)
                        statsRow(for: active.id)
                    } else {
                        startProjectCTA
                    }
                    onTheNeedlesSection
                }
                .padding(.bottom, 32)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: greeting

    private var greeting: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(todayLabel).meta()
            Text(greetingText)
                .font(AppFont.serif(34))
                .foregroundStyle(Palette.walnut)
            if let subtitle = greetingSubtitle {
                Text(subtitle)
                    .font(.system(size: 15))
                    .foregroundStyle(Palette.walnutSoft)
                    .padding(.top, 2)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 18)
    }

    private var greetingText: String {
        if let name = account.displayName, !name.isEmpty {
            return "Hello, \(name)."
        }
        return "Hello."
    }

    private var greetingSubtitle: String? {
        guard active != nil else { return "Cast on something — your library is waiting." }
        return nil
    }

    // MARK: start CTA (no active project)

    private var startProjectCTA: some View {
        SoftCard {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Start something new").eyebrow(color: Palette.primaryDark)
                    Text("Pick a pattern and we'll set up the counter.")
                        .font(.system(size: 14))
                        .foregroundStyle(Palette.walnutSoft)
                        .lineSpacing(2)
                }
                if flags.pdfImportEnabled {
                    HStack(spacing: 10) {
                        NavigationLink(value: Route.importPDF) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.up.doc")
                                Text("Import PDF")
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Palette.primary))
                        }
                        .buttonStyle(PressScaleStyle())
                        // UI tests look for this id — keep in sync with WindyKnitsUITests.
                        .accessibilityIdentifier("today.start.importPDF")

                        NavigationLink(value: Route.manualPattern) {
                            HStack(spacing: 6) {
                                Image(systemName: "pencil.line")
                                Text("Add manually")
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Palette.walnut)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Palette.creamSoft))
                        }
                        .buttonStyle(PressScaleStyle())
                        // Same id as the single-button case so tests can find
                        // the "go to manual editor" entry point regardless of
                        // the feature-flag state.
                        .accessibilityIdentifier("today.start.addPattern")
                    }
                } else {
                    // No PDF import path, so "manually" loses its meaning —
                    // there's no other way to add a pattern.
                    NavigationLink(value: Route.manualPattern) {
                        HStack(spacing: 6) {
                            Image(systemName: "pencil.line")
                            Text("Add pattern")
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Palette.primary))
                    }
                    .buttonStyle(PressScaleStyle())
                    .accessibilityIdentifier("today.start.addPattern")
                }
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: stats

    private func statsRow(for projectId: String) -> some View {
        StatsRow(projectId: projectId)
    }

    // MARK: on the needles

    private var onTheNeedlesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("On the needles")
                    .font(AppFont.serif(18))
                    .foregroundStyle(Palette.walnut)
                Spacer()
                Button("See all") { switchTab(.projects) }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.primaryDark)
            }
            .padding(.horizontal, 24)

            VStack(spacing: 10) {
                if otherActive.isEmpty {
                    onTheNeedlesEmpty
                } else {
                    ForEach(otherActive) { p in
                        NavigationLink(value: Route.project(p.id)) {
                            ProjectRow(project: p)
                        }
                        .buttonStyle(.plain)
                    }
                }
                NavigationLink(value: flags.pdfImportEnabled ? Route.importPDF : Route.manualPattern) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                        Text(flags.pdfImportEnabled ? "Import a pattern PDF" : "Add a pattern")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.walnutSoft)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                            .foregroundStyle(Palette.lineStrong)
                    )
                    .padding(.top, 4)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
        }
        .padding(.top, 14)
    }

    private var onTheNeedlesEmpty: some View {
        Text(active == nil
             ? "Nothing on the needles yet."
             : "Just the one active project for now.")
            .meta(size: 12)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 14)
    }
}

// MARK: - Active project card

/// Renders the "currently knitting" card for a specific project. Owns its own
/// `@AppStorage` bindings keyed by `projectId`, so the parent doesn't have to
/// bind to a static id and the card re-mounts cleanly when the active project
/// changes.
private struct ActiveProjectCard: View {
    let project: Project
    @Binding var path: NavigationPath
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage private var currentRow: Int
    @AppStorage private var historyJSON: String

    init(project: Project, path: Binding<NavigationPath>) {
        self.project = project
        self._path = path
        let store = SharedStore.defaults
        _currentRow = AppStorage(wrappedValue: 0,
                                 SharedStore.Keys.rows(project.id), store: store)
        _historyJSON = AppStorage(wrappedValue: "[]",
                                  SharedStore.Keys.history(project.id), store: store)
    }

    /// Length of one chart repeat — used to scope progress to "current
    /// section" rather than the whole project. Charts without an explicit
    /// repeat collapse to the project's full row total.
    private var sectionTotalRows: Int {
        let rpr = project.pattern?.rowsPerRepeat ?? 0
        if rpr > 0 {
            // Use the section's row count if available; otherwise fall back to
            // the chart length.
            return project.pattern?.sections.first?.rowCount ?? project.pattern?.rows.count ?? rpr
        }
        return max(1, project.rowsTotal)
    }

    private var sectionProgress: Double {
        guard sectionTotalRows > 0 else { return 0 }
        return min(1, max(0, Double(currentRow) / Double(sectionTotalRows)))
    }
    private var sectionPercentLabel: String {
        "\(Int((sectionProgress * 100).rounded()))%"
    }

    var body: some View {
        SoftCard {
            VStack(alignment: .leading, spacing: 0) {
                Button { path.append(Route.project(project.id)) } label: {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(alignment: .top, spacing: 16) {
                            PhotoPlaceholder(label: "photo", tint: project.swatch)
                                .frame(width: 86, height: 86)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Currently knitting").eyebrow(color: Palette.primaryDark)
                                Text(project.title)
                                    .font(AppFont.serif(22))
                                    .foregroundStyle(Palette.walnut)
                                    .padding(.top, 2)
                                Text(project.designer).meta()
                            }
                            Spacer(minLength: 0)
                        }

                        HStack(alignment: .firstTextBaseline) {
                            Text("Row \(Text("\(currentRow)").foregroundStyle(Palette.primaryDark).fontWeight(.semibold)) / \(sectionTotalRows)")
                                .foregroundStyle(Palette.walnutSoft)
                                .font(AppFont.mono(13))
                            Spacer()
                            Text(sectionPercentLabel)
                                .font(AppFont.mono(12))
                                .foregroundStyle(Palette.walnutMute)
                        }
                        .padding(.top, 18)

                        ProgressBar(value: sectionProgress)
                            .padding(.top, 8)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                HStack(spacing: 10) {
                    Button { path.append(Route.pattern(project.id)) } label: {
                        Text("Continue knitting")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Palette.primary)
                            )
                    }
                    .buttonStyle(PressScaleStyle())

                    Button { path.append(Route.counter(project.id)) } label: {
                        Image(systemName: "number.square")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Palette.walnut)
                            .frame(width: 50, height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Palette.creamSoft)
                            )
                    }
                    .buttonStyle(PressScaleStyle())
                }
                .padding(.top, 18)
            }
        }
        .padding(.horizontal, 16)
        .onChange(of: scenePhase) { _, new in
            if new == .active { reloadFromAppGroup() }
        }
        .onAppear(perform: reloadFromAppGroup)
    }

    /// See CounterScreen.reloadFromAppGroup — same fix for cross-process
    /// writes by the Live Activity intent.
    private func reloadFromAppGroup() {
        let d = SharedStore.defaults
        currentRow = d.integer(forKey: SharedStore.Keys.rows(project.id))
        historyJSON = d.string(forKey: SharedStore.Keys.history(project.id)) ?? "[]"
    }
}

// MARK: - Stats row

/// Per-project knit-time stats. Self-contained so it can subscribe to the
/// active project's history key directly via `@AppStorage`.
private struct StatsRow: View {
    let projectId: String
    @AppStorage private var historyJSON: String

    init(projectId: String) {
        self.projectId = projectId
        _historyJSON = AppStorage(wrappedValue: "[]",
                                  SharedStore.Keys.history(projectId),
                                  store: SharedStore.defaults)
    }

    private var history: [CompletedRow] { CounterHistory.decode(historyJSON) }
    private var rowsThisWeekValue: String { "\(CounterHistory.rowsThisWeek(history))" }
    private var timeTodayDisplay: (value: String, unit: String) {
        Self.formatDuration(CounterHistory.timeToday(history))
    }
    private var totalTimeDisplay: (value: String, unit: String) {
        Self.formatDuration(CounterHistory.totalTime(history))
    }

    private static func formatDuration(_ seconds: TimeInterval) -> (value: String, unit: String) {
        seconds < 3600
            ? ("\(Int(seconds / 60))", "min")
            : ("\(Int(seconds / 3600))", "hr")
    }

    var body: some View {
        HStack(spacing: 10) {
            StatTile(label: "This week", value: rowsThisWeekValue, unit: "rows")
            StatTile(label: "Time today",
                     value: timeTodayDisplay.value,
                     unit: timeTodayDisplay.unit)
            StatTile(label: "Total time",
                     value: totalTimeDisplay.value,
                     unit: totalTimeDisplay.unit)
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
        .padding(.bottom, 12)
    }
}

struct StatTile: View {
    let label: String
    let value: String
    let unit: String

    var body: some View {
        SoftCard(padding: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(label).eyebrow()
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value)
                        .font(AppFont.mono(22, weight: .semibold))
                        .foregroundStyle(Palette.walnut)
                    Text(unit)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Palette.walnutMute)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct ProjectRow: View {
    let project: Project

    var body: some View {
        SoftCard(padding: 12) {
            HStack(spacing: 14) {
                YarnSwatch(color: project.swatch)
                VStack(alignment: .leading, spacing: 2) {
                    Text(project.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Palette.walnut)
                    Text("\(project.designer) · \(project.lastWorked)").meta(size: 12)
                }
                Spacer(minLength: 6)
                VStack(alignment: .trailing, spacing: 6) {
                    Text("\(project.rowsDone)/\(project.rowsTotal)")
                        .font(AppFont.mono(12))
                        .foregroundStyle(Palette.walnutMute)
                    ProgressBar(value: project.progress, height: 4).frame(width: 56)
                }
            }
        }
    }
}

#Preview {
    @Previewable @State var path = NavigationPath()
    let account = UserAccount()
    account.adopt(.init(userID: "preview", displayName: "Windy", email: nil))
    return NavigationStack(path: $path) {
        TodayScreen(path: $path)
            .navigationDestinationForRoutes()
    }
    .environment(PatternStore.shared)
    .environment(FeatureFlags.shared)
    .environment(account)
    .tint(Palette.primary)
}
