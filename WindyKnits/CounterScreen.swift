import ActivityKit
import SwiftUI

struct CounterScreen: View {
    let projectId: String
    var showsBackButton: Bool

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(PatternStore.self) private var store

    // Persisted per project, so each project keeps its own counters across launches.
    // `repeats` and `rowInRepeat` are derived from `rows` — no separate storage.
    @AppStorage private var rows: Int
    @AppStorage private var stitches: Int
    @AppStorage private var linked: Bool
    @AppStorage private var activeRaw: String
    // Completed-row log as JSON. Each forward step in `rows` appends a stamped
    // entry; capped at 50 to keep UserDefaults light.
    @AppStorage private var historyJSON: String
    // Holds the just-completed row number for ~1.3s after a single-row advance
    // so the celebration chip + card pulse can animate. nil = no celebration.
    @State private var celebrationRow: Int? = nil
    // Same idea, but for finishing a chart repeat — bigger flourish, ~2s
    // lifetime, suppresses the row chip when both fire on the same advance.
    @State private var celebrationRepeat: Int? = nil
    // Increment to trigger a new confetti burst on the primary card.
    @State private var confettiTrigger: Int = 0 
    // True while a Live Activity is broadcasting this project to the Lock
    // Screen. Mirrors `Activity.activities` — refreshed on appear and after
    // start/end calls.
    @State private var sessionActive: Bool = false

    init(projectId: String, showsBackButton: Bool = true) {
        self.projectId = projectId
        self.showsBackButton = showsBackButton
        let store = SharedStore.defaults
        _rows        = AppStorage(wrappedValue: 0,
                                  SharedStore.Keys.rows(projectId), store: store)
        _stitches    = AppStorage(wrappedValue: 0,
                                  SharedStore.Keys.stitches(projectId), store: store)
        _linked      = AppStorage(wrappedValue: true,
                                  SharedStore.Keys.linked(projectId), store: store)
        _activeRaw   = AppStorage(wrappedValue: ActiveCounter.stitches.rawValue,
                                  SharedStore.Keys.active(projectId), store: store)
        _historyJSON = AppStorage(wrappedValue: "[]",
                                  SharedStore.Keys.history(projectId), store: store)
    }

    /// Remembers which counter the user just opened so the Counter tab can
    /// resume on it next time it's selected. Lives in `.onAppear` — not
    /// `init` — because `CounterTabRoot` observes the same key and would
    /// re-render → re-mount this view in a loop.
    private func rememberAsLastActiveProject() {
        SharedStore.defaults.set(projectId,
                                 forKey: SharedStore.Keys.lastActiveProjectId)
    }

    private var repeats: Int {
        rows < 1 ? 0 : ((rows - 1) / rowsPerRepeat) + 1
    }
    private var rowInRepeat: Int {
        rows < 1 ? 0 : ((rows - 1) % rowsPerRepeat) + 1
    }

    enum ActiveCounter: String { case rows, stitches, repeats }

    private var active: ActiveCounter {
        get { ActiveCounter(rawValue: activeRaw) ?? .stitches }
        nonmutating set { activeRaw = newValue.rawValue }
    }

    // Pulls the stitch target for the row the user is currently working on —
    // that's `rows + 1` since `rows` counts completed rows. Returns 0 to mean
    // "no goal set" (no pattern, or the pattern doesn't have a stitch count
    // on this row).
    private var stitchGoal: Int {
        let target = rows + 1
        return project?.pattern?.rows.first(where: { $0.n == target })?.sts ?? 0
    }
    private var hasStitchGoal: Bool { stitchGoal > 0 }
    private var rowsGoal: Int {
        max(1, project?.rowsTotal ?? 1)
    }
    /// Length of one chart repeat. Charts that don't declare one (the common
    /// case for imported/manual patterns) treat the whole pattern as a single
    /// repeat, so the repeat counter degrades to "1 of 1" gracefully.
    private var rowsPerRepeat: Int {
        max(1, project?.pattern?.rowsPerRepeat ?? rowsGoal)
    }
    private var repeatGoal: Int {
        rowsPerRepeat > 0 ? max(1, rowsGoal / rowsPerRepeat) : 1
    }

    /// The resolved project, or a placeholder shown for one frame while the
    /// `.onAppear` below dismisses the screen for an unknown id.
    private var project: Project? { store.project(id: projectId) }

    private var completedRows: [CompletedRow] {
        CounterHistory.decode(historyJSON)
    }

    private func writeCompletedRows(_ list: [CompletedRow]) {
        guard let data = try? JSONEncoder().encode(list),
              let str = String(data: data, encoding: .utf8) else { return }
        historyJSON = str
    }

    // Forward step: append a stamped entry for each row crossed. Multi-row
    // jumps (the repeat tap) record one entry per row, all timestamped now.
    private func recordCompletions(from oldRows: Int, to newRows: Int) {
        guard newRows > oldRows else { return }
        let now = Date()
        var list = completedRows
        for n in oldRows..<newRows where n >= 1 {
            let s = project?.pattern?.rows.first(where: { $0.n == n })?.sts ?? 0
            list.append(.init(n: n, timestamp: now, sts: s))
        }
        if list.count > 50 { list = Array(list.suffix(50)) }
        writeCompletedRows(list)
    }

    var body: some View {
        Group {
            if project == nil {
                missingProjectState
            } else {
                content
            }
        }
            .overlay(alignment: .top) {
                celebrationOverlay
            }
            .toolbar(.hidden, for: .navigationBar)
            .onChange(of: rows, handleRowsChange)
            .onChange(of: scenePhase) { _, new in
                if new == .active { reloadFromAppGroup() }
            }
            .onAppear {
                refreshSessionState()
                reloadFromAppGroup()
                rememberAsLastActiveProject()
            }
            .sensoryFeedback(.increase, trigger: stitches, condition: didIncrease)
            .sensoryFeedback(.impact(weight: .heavy), trigger: rows, condition: didIncrease)
            .sensoryFeedback(.success, trigger: repeats, condition: didIncrease)
    }

    private var missingProjectState: some View {
        ZStack {
            Palette.cream.ignoresSafeArea()
            VStack(spacing: 14) {
                navBar
                Spacer(minLength: 20)
                Image(systemName: "questionmark.folder")
                    .font(.system(size: 28, weight: .regular))
                    .foregroundStyle(Palette.walnutMute)
                    .frame(width: 72, height: 72)
                    .background(RoundedRectangle(cornerRadius: 20).fill(Palette.creamWarm))
                Text("Project not found.")
                    .font(AppFont.serif(20))
                    .foregroundStyle(Palette.walnut)
                Text("This counter's project was removed. Pick another from your library.")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.walnutMute)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .frame(maxWidth: 280)
                if showsBackButton {
                    Button { dismiss() } label: {
                        Text("Back")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Palette.walnut)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(Palette.creamSoft))
                    }
                    .buttonStyle(PressScaleStyle())
                }
                Spacer()
            }
        }
    }

    /// Pull counter values back out of the App Group UserDefaults and write
    /// them through the @AppStorage setters. `IncrementRowIntent` runs in
    /// the widget extension process when the Live Activity +1 button is
    /// tapped, and those writes don't notify the app's in-process KVO — so
    /// without this re-sync, the counter screen shows a stale value until
    /// the next in-app mutation forces a read.
    private func reloadFromAppGroup() {
        let d = SharedStore.defaults
        rows = d.integer(forKey: SharedStore.Keys.rows(projectId))
        stitches = d.integer(forKey: SharedStore.Keys.stitches(projectId))
        historyJSON = d.string(forKey: SharedStore.Keys.history(projectId)) ?? "[]"
    }

    // MARK: Live Activity

    private func refreshSessionState() {
        sessionActive = Activity<CounterActivityAttributes>.activities
            .contains { $0.attributes.projectId == projectId }
    }

    private func toggleSession() {
        if sessionActive { endSession() } else { startSession() }
    }

    private func startSession() {
        guard let project else { return }
        // Mirror the pattern's per-row instruction text into the App Group
        // so the Live Activity intents can populate ContentState.currentRowText
        // without linking PatternStore.
        seedRowTexts()

        let attrs = CounterActivityAttributes(
            projectId: projectId,
            projectTitle: project.title,
            rowsTotal: rowsGoal)
        let state = CounterActivityAttributes.ContentState(
            rows: rows,
            currentRowText: currentRowInstruction)
        do {
            _ = try Activity.request(
                attributes: attrs,
                content: ActivityContent(state: state, staleDate: nil),
                pushType: nil)
            sessionActive = true
        } catch {
            // The most common reason this fails is the user disabling Live
            // Activities for the app in Settings. We don't surface an error
            // because the toggle just won't flip — quiet failure is fine here.
        }
    }

    private func seedRowTexts() {
        var texts: [Int: String] = [:]
        if let p = project?.pattern {
            for row in p.rows { texts[row.n] = row.text }
        }
        SharedStore.setRowTexts(texts, projectId: projectId)
    }

    private var currentRowInstruction: String? {
        SharedStore.rowText(forRow: rows + 1, projectId: projectId)
    }

    private func endSession() {
        let final = CounterActivityAttributes.ContentState(
            rows: rows, currentRowText: currentRowInstruction)
        let matching = Activity<CounterActivityAttributes>.activities
            .filter { $0.attributes.projectId == projectId }
        Task {
            for activity in matching {
                await activity.end(
                    ActivityContent(state: final, staleDate: nil),
                    dismissalPolicy: .immediate)
            }
        }
        sessionActive = false
    }

    /// Push the latest row count into any active Live Activity for this
    /// project. Idempotent — safe to call on every row change. We don't
    /// branch on `sessionActive` because that's a UI mirror, not a source
    /// of truth.
    private func syncActivityRows() {
        let matching = Activity<CounterActivityAttributes>.activities
            .filter { $0.attributes.projectId == projectId }
        guard !matching.isEmpty else { return }
        let state = CounterActivityAttributes.ContentState(
            rows: rows, currentRowText: currentRowInstruction)
        Task {
            for activity in matching {
                await activity.update(
                    ActivityContent(state: state, staleDate: nil))
            }
        }
    }

    @ViewBuilder
    private var celebrationOverlay: some View {
        if let r = celebrationRepeat {
            celebrationBanner(repeatNumber: r)
        } else if let n = celebrationRow {
            celebrationChip(row: n)
        }
    }

    private func handleRowsChange(_ oldValue: Int, _ newValue: Int) {
        recordCompletions(from: oldValue, to: newValue)
        syncActivityRows()
        guard newValue > oldValue, oldValue >= 1 else { return }
        let rpr = rowsPerRepeat
        let oldRepeat = ((oldValue - 1) / rpr) + 1
        let newRepeat = ((newValue - 1) / rpr) + 1
        if newRepeat > oldRepeat {
            // A repeat boundary was crossed — celebrate the just-finished one.
            // This supersedes any row chip that the same advance would have
            // triggered.
            celebrate(repeatJustCompleted: newRepeat - 1)
        } else if newValue - oldValue == 1 {
            // Single-row completion within a repeat. Multi-row jumps that don't
            // cross a boundary fall through silently (haptic only).
            celebrate(rowJustCompleted: oldValue)
        }
    }

    private func didIncrease(_ old: Int, _ new: Int) -> Bool { new > old }

    private var content: some View {
        ZStack {
            Palette.cream.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    navBar
                    primaryPad
                    secondaryRow
                    linkedCard
                    sessionCard
                    historyHeader
                    historyCard
                    Color.clear.frame(height: 40)
                }
            }
        }
    }

    private func celebrate(rowJustCompleted n: Int) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) {
            celebrationRow = n
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.3))
            withAnimation(.easeOut(duration: 0.35)) {
                celebrationRow = nil
            }
        }
    }

    private func celebrate(repeatJustCompleted n: Int) {
        confettiTrigger += 1
        withAnimation(.spring(response: 0.45, dampingFraction: 0.55)) {
            celebrationRepeat = n
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.0))
            withAnimation(.easeOut(duration: 0.45)) {
                celebrationRepeat = nil
            }
        }
    }

    private func celebrationChip(row: Int) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14, weight: .semibold))
            Text("Row \(row) done")
                .font(.system(size: 13, weight: .semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Capsule().fill(Palette.accent))
        .shadow(color: Palette.accent.opacity(0.45), radius: 12, y: 6)
        .padding(.top, 70)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private func celebrationBanner(repeatNumber: Int) -> some View {
        VStack(spacing: 3) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .bold))
                Text("Repeat \(repeatNumber) done")
                    .font(.system(size: 16, weight: .bold))
            }
            Text("\(rowsPerRepeat) rows complete")
                .font(.system(size: 11, weight: .medium))
                .opacity(0.85)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(LinearGradient(
                    colors: [Palette.accent, Palette.primary],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
        )
        .shadow(color: Palette.accent.opacity(0.5), radius: 18, y: 10)
        .padding(.top, 60)
        .transition(.scale(scale: 0.6).combined(with: .opacity))
    }

    // MARK: nav

    private var navBar: some View {
        HStack {
            if showsBackButton {
                CircleIconButton(system: "chevron.left") { dismiss() }
            } else {
                Color.clear.frame(width: 38, height: 38)
            }
            Spacer()
            Text(project?.title ?? "Counter")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Palette.walnut)
            Spacer()
            // Reserve the right slot so the title stays centred.
            Color.clear.frame(width: 38, height: 38)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 14)
    }

    // MARK: primary pad

    private var primaryValue: Int {
        switch active {
        case .stitches: return stitches
        case .rows:     return rows
        case .repeats:  return repeats
        }
    }
    private var primaryLabel: String {
        switch active {
        case .stitches: return "Stitches in row"
        case .rows:     return "Rows knit"
        case .repeats:  return "Repeat"
        }
    }
    private var primaryHint: String {
        switch active {
        case .stitches:
            guard hasStitchGoal else { return "count freely · no goal on this row" }
            return linked ? "of \(stitchGoal) → auto-bumps row" : "of \(stitchGoal)"
        case .rows:     return "of \(rowsGoal) rows"
        case .repeats:  return "of \(repeatGoal) chart repeats — row \(rowInRepeat) of \(rowsPerRepeat)"
        }
    }
    private var primaryProgress: Double {
        switch active {
        case .stitches: return hasStitchGoal ? Double(stitches) / Double(stitchGoal) : 0
        case .rows:     return Double(rows) / Double(rowsGoal)
        case .repeats:  return Double(repeats) / Double(repeatGoal)
        }
    }

    private var primaryPad: some View {
        VStack(spacing: 8) {
            Text(primaryLabel).eyebrow(color: .white.opacity(0.75))
            Text("\(primaryValue)")
                .font(AppFont.serif(112))
                .foregroundStyle(.white)
                .monospacedDigit()
                .padding(.top, 8)
                // UI tests read the current primary counter value via this id.
                .accessibilityIdentifier("counter.primaryValue")
            Text(primaryHint)
                .font(AppFont.mono(13))
                .foregroundStyle(.white.opacity(0.85))

            // goal bar
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.20))
                    Capsule()
                        .fill(.white)
                        .frame(width: max(0, min(1, primaryProgress)) * g.size.width)
                        .animation(.easeOut(duration: 0.25), value: primaryProgress)
                }
            }
            .frame(height: 5)
            .padding(.top, 16)

            HStack(spacing: 8) {
                circlePill(system: "minus") { changeActive(by: -1) }
                Text("tap card to add")
                    .font(AppFont.mono(12))
                    .foregroundStyle(.white.opacity(0.75))
                    .padding(.horizontal, 14)
                circlePill(system: "arrow.counterclockwise") { resetActive() }
            }
            .padding(.top, 16)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.horizontal, 24)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Palette.primary.opacity(0.88),
                            Palette.primary
                        ],
                        startPoint: .top, endPoint: .bottom)
                )
                .shadow(color: Palette.primary.opacity(0.5), radius: 20, x: 0, y: 14)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(isCelebrating ? 0.55 : 0), lineWidth: 3)
        )
        .overlay {
            ConfettiBurst(triggerID: confettiTrigger)
                .allowsHitTesting(false)
        }
        .scaleEffect(celebrationRepeat != nil ? 1.05
                     : celebrationRow != nil ? 1.025
                     : 1.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.55), value: celebrationRow)
        .animation(.spring(response: 0.4, dampingFraction: 0.55), value: celebrationRepeat)
        .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .onTapGesture { tapPrimary() }
        // Keep children (incl. counter.primaryValue) individually accessible.
        // Without this, attaching an identifier to the pad would merge all
        // children into one combined element and hide the value Text.
        .accessibilityElement(children: .contain)
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    private var isCelebrating: Bool {
        celebrationRow != nil || celebrationRepeat != nil
    }

    private func circlePill(system: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(Circle().fill(.white.opacity(0.20)))
        }
        .buttonStyle(PressScaleStyle())
    }

    private func tapPrimary() {
        switch active {
        case .stitches:
            let next = stitches + 1
            if linked, hasStitchGoal, next >= stitchGoal {
                rows += 1
                stitches = 0
            } else {
                stitches = next
            }
        case .rows:    rows += 1
        case .repeats: advanceRepeat()
        }
    }

    private func changeActive(by delta: Int) {
        switch active {
        case .stitches: stitches = max(0, stitches + delta)
        case .rows:     rows     = max(0, rows + delta)
        case .repeats:
            if delta > 0 { advanceRepeat() }
            else if delta < 0 { rewindRepeat() }
        }
    }

    private func resetActive() {
        switch active {
        case .stitches: stitches = 0
        case .rows:     rows = 0; writeCompletedRows([])
        case .repeats:  rows = 0; writeCompletedRows([])
        }
    }

    // Snap to the first row of the next repeat ("just finished this repeat").
    // Clamped to the section end, so a tap on the last repeat is a no-op.
    private func advanceRepeat() {
        let nextStart = repeats * rowsPerRepeat + 1
        rows = min(rowsGoal, nextStart)
    }

    // If we're mid-repeat, snap to the start of the current repeat; if already
    // at a repeat start, go back to the previous repeat's start.
    private func rewindRepeat() {
        let currentStart = max(1, (repeats - 1) * rowsPerRepeat + 1)
        rows = rows > currentStart ? currentStart : max(0, currentStart - rowsPerRepeat)
    }

    // MARK: secondary row

    private var secondaryRow: some View {
        HStack(spacing: 10) {
            ForEach(secondaryCounters, id: \.id) { c in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        active = c.id
                    }
                } label: {
                    VStack(spacing: 4) {
                        Text(c.label).eyebrow()
                        Text("\(c.value)")
                            .font(AppFont.serif(36))
                            .foregroundStyle(Palette.walnut)
                            .monospacedDigit()
                        Text(c.goal > 0 ? "of \(c.goal)" : "no goal").meta(size: 11)
                    }
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(Palette.paper)
                            .shadow(color: Palette.walnut.opacity(0.12),
                                    radius: 11, x: 0, y: 8)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(Palette.line, lineWidth: 0.5)
                    )
                }
                .buttonStyle(PressScaleStyle())
                // UI tests tap `counter.secondary.rows` etc. to switch active mode.
                .accessibilityIdentifier("counter.secondary.\(c.id.rawValue)")
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 14)
    }

    private struct SecondaryCounter {
        let id: ActiveCounter
        let label: String
        let value: Int
        let goal: Int
    }

    private var secondaryCounters: [SecondaryCounter] {
        let all: [SecondaryCounter] = [
            .init(id: .rows,     label: "Rows",     value: rows,     goal: rowsGoal),
            .init(id: .stitches, label: "Stitches", value: stitches, goal: stitchGoal),
            .init(id: .repeats,  label: "Repeats",  value: repeats,  goal: repeatGoal)
        ]
        return all.filter { $0.id != active }
    }

    // MARK: linked toggle

    private var linkedCard: some View {
        SoftCard(padding: 14) {
            HStack(spacing: 12) {
                ZStack(alignment: linked ? .trailing : .leading) {
                    Capsule()
                        .fill(linked ? Palette.accent : Palette.creamSoft)
                        .frame(width: 40, height: 24)
                    Circle()
                        .fill(.white)
                        .frame(width: 20, height: 20)
                        .padding(2)
                        .shadow(color: .black.opacity(0.2), radius: 1, y: 1)
                }
                .animation(.spring(response: 0.25), value: linked)
                .onTapGesture { linked.toggle() }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Link stitches to rows")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Palette.walnut)
                    Text(hasStitchGoal
                         ? "When you hit \(stitchGoal), the row counter advances."
                         : "Add a stitch count to this row to auto-advance.")
                        .meta(size: 12)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
    }

    // MARK: Lock Screen session toggle

    private var sessionCard: some View {
        SoftCard(padding: 14) {
            HStack(spacing: 12) {
                ZStack(alignment: sessionActive ? .trailing : .leading) {
                    Capsule()
                        .fill(sessionActive ? Palette.accent : Palette.creamSoft)
                        .frame(width: 40, height: 24)
                    Circle()
                        .fill(.white)
                        .frame(width: 20, height: 20)
                        .padding(2)
                        .shadow(color: .black.opacity(0.2), radius: 1, y: 1)
                }
                .animation(.spring(response: 0.25), value: sessionActive)
                .onTapGesture { toggleSession() }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Lock Screen counter")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Palette.walnut)
                    Text(sessionActive
                         ? "Active — tap +1 on your Lock Screen to add rows."
                         : "Show this counter on your Lock Screen for the session.")
                        .meta(size: 12)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
    }

    // MARK: history

    private var historyHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Recent rows").eyebrow()
            Spacer()
            Text("last 6")
                .font(AppFont.mono(11))
                .foregroundStyle(Palette.walnutMute)
        }
        .padding(.horizontal, 24)
        .padding(.top, 14)
        .padding(.bottom, 4)
    }

    private struct HistoryEntry: Identifiable {
        let id: String
        let n: Int
        let timestamp: Date?
        let sts: Int
        let ongoing: Bool
    }

    private var historyEntries: [HistoryEntry] {
        var entries: [HistoryEntry] = []
        if rows >= 1 {
            entries.append(.init(id: "ongoing", n: rows, timestamp: nil,
                                 sts: stitches, ongoing: true))
        }
        // Show the 5 most recent completions newest-first.
        for c in completedRows.suffix(5).reversed() {
            entries.append(.init(
                id: "\(c.n)-\(c.timestamp.timeIntervalSince1970)",
                n: c.n,
                timestamp: c.timestamp,
                sts: c.sts,
                ongoing: false
            ))
        }
        return entries
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f
    }()

    private var historyCard: some View {
        SoftCard(padding: 4) {
            VStack(spacing: 0) {
                ForEach(Array(historyEntries.enumerated()), id: \.element.id) { idx, r in
                    HStack(spacing: 8) {
                        Text("\(r.n)")
                            .font(AppFont.mono(13, weight: .semibold))
                            .foregroundStyle(r.ongoing ? Palette.primaryDark : Palette.walnut)
                            .frame(width: 36, alignment: .leading)
                        if r.ongoing {
                            HStack(spacing: 6) {
                                Circle().fill(Palette.primary).frame(width: 6, height: 6)
                                Text("in progress")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Palette.primaryDark)
                            }
                        } else if let ts = r.timestamp {
                            Text(Self.relativeFormatter.localizedString(for: ts, relativeTo: Date()))
                                .font(.system(size: 13))
                                .foregroundStyle(Palette.walnutSoft)
                        }
                        Spacer(minLength: 0)
                        Text("\(r.sts) st")
                            .font(AppFont.mono(12))
                            .foregroundStyle(Palette.walnutMute)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    if idx < historyEntries.count - 1 {
                        Rectangle().fill(Palette.line).frame(height: 0.5)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
    }
}

private struct ConfettiBurst: View {
    let triggerID: Int
    @State private var progress: Double = 1   // 0 = at center, 1 = scattered + faded
    @State private var particles: [Particle] = []

    private struct Particle: Identifiable {
        let id = UUID()
        let angle: Double
        let distance: CGFloat
        let size: CGFloat
        let color: Color
        let rotation: Double
    }

    var body: some View {
        ZStack {
            ForEach(particles) { p in
                RoundedRectangle(cornerRadius: 2)
                    .fill(p.color)
                    .frame(width: p.size, height: p.size * 1.4)
                    .rotationEffect(.degrees(p.rotation * progress))
                    .offset(
                        x: cos(p.angle * .pi / 180) * p.distance * progress,
                        y: sin(p.angle * .pi / 180) * p.distance * progress
                    )
                    .opacity(1 - progress)
            }
        }
        .onChange(of: triggerID) { _, _ in burst() }
    }

    private func burst() {
        particles = (0..<20).map { i in
            Particle(
                angle: Double(i) * (360.0 / 20.0) + Double.random(in: -10...10),
                distance: CGFloat.random(in: 90...170),
                size: CGFloat.random(in: 5...9),
                color: [Palette.accent, Palette.primary, Palette.primaryDark, .white]
                    .randomElement()!,
                rotation: Double.random(in: -270...270)
            )
        }
        progress = 0
        withAnimation(.easeOut(duration: 1.0)) {
            progress = 1
        }
    }
}

#Preview {
    NavigationStack { CounterScreen(projectId: "p1") }
        .environment(PatternStore.shared)
        .tint(Palette.primary)
}
