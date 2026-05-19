import SwiftUI

struct CounterScreen: View {
    let projectId: String
    var showsBackButton: Bool

    @Environment(\.dismiss) private var dismiss

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

    init(projectId: String = "p1", showsBackButton: Bool = true) {
        self.projectId = projectId
        self.showsBackButton = showsBackButton
        _rows        = AppStorage(wrappedValue: 5,    "counter.\(projectId).rows")
        _stitches    = AppStorage(wrappedValue: 34,   "counter.\(projectId).stitches")
        _linked      = AppStorage(wrappedValue: true, "counter.\(projectId).linked")
        _activeRaw   = AppStorage(wrappedValue: ActiveCounter.stitches.rawValue,
                                  "counter.\(projectId).active")
        _historyJSON = AppStorage(wrappedValue: "[]", "counter.\(projectId).history")
    }

    private var repeats: Int {
        rows < 1 ? 0 : ((rows - 1) / SampleData.rowsPerRepeat) + 1
    }
    private var rowInRepeat: Int {
        rows < 1 ? 0 : ((rows - 1) % SampleData.rowsPerRepeat) + 1
    }

    enum ActiveCounter: String { case rows, stitches, repeats }

    private var active: ActiveCounter {
        get { ActiveCounter(rawValue: activeRaw) ?? .stitches }
        nonmutating set { activeRaw = newValue.rawValue }
    }

    // Pulls the stitch target from the pattern data for the current row, so
    // linked auto-advance fires at the right count for variable-stitch rows
    // (e.g. increase/decrease rows). Falls back to 96 when we're outside the
    // sample-pattern range.
    private var stitchGoal: Int {
        SampleData.pattern.first(where: { $0.n == rows })?.sts ?? 24
    }
    private var repeatGoal: Int {
        SampleData.patternTotalRows / SampleData.rowsPerRepeat
    }
    private var rowsGoal: Int { SampleData.patternTotalRows }

    private var project: Project { SampleData.project(id: projectId) }

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
            let s = SampleData.pattern.first(where: { $0.n == n })?.sts ?? 24
            list.append(.init(n: n, timestamp: now, sts: s))
        }
        if list.count > 50 { list = Array(list.suffix(50)) }
        writeCompletedRows(list)
    }

    var body: some View {
        content
            .overlay(alignment: .top) {
                if let n = celebrationRow {
                    celebrationChip(row: n)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .onChange(of: rows) { oldValue, newValue in
                recordCompletions(from: oldValue, to: newValue)
                // Single-row completions get the chip; multi-row jumps (repeat
                // tap) rely on the success haptic alone, since "Row 5 done"
                // would be misleading after an 8-row jump.
                if newValue - oldValue == 1, oldValue >= 1 {
                    celebrate(rowJustCompleted: oldValue)
                }
            }
            .sensoryFeedback(.increase, trigger: stitches) { old, new in new > old }
            .sensoryFeedback(.impact(weight: .heavy), trigger: rows) { old, new in new > old }
            .sensoryFeedback(.success, trigger: repeats) { old, new in new > old }
    }

    private var content: some View {
        ZStack {
            Palette.cream.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    navBar
                    primaryPad
                    secondaryRow
                    linkedCard
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

    // MARK: nav

    private var navBar: some View {
        HStack {
            if showsBackButton {
                CircleIconButton(system: "chevron.left") { dismiss() }
            } else {
                Color.clear.frame(width: 38, height: 38)
            }
            Spacer()
            Text(project.title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Palette.walnut)
            Spacer()
            CircleIconButton(system: "ellipsis") {}
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
        case .stitches: return linked ? "of \(stitchGoal) → auto-bumps row" : "of \(stitchGoal)"
        case .rows:     return "of \(rowsGoal) — yoke"
        case .repeats:  return "of \(repeatGoal) chart repeats — row \(rowInRepeat) of \(SampleData.rowsPerRepeat)"
        }
    }
    private var primaryProgress: Double {
        switch active {
        case .stitches: return Double(stitches) / Double(stitchGoal)
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
                .stroke(Color.white.opacity(celebrationRow != nil ? 0.55 : 0), lineWidth: 3)
        )
        .scaleEffect(celebrationRow != nil ? 1.025 : 1.0)
        .animation(.spring(response: 0.35, dampingFraction: 0.55), value: celebrationRow)
        .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .onTapGesture { tapPrimary() }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
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
            if linked, next >= stitchGoal {
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
        let nextStart = repeats * SampleData.rowsPerRepeat + 1
        rows = min(SampleData.patternTotalRows, nextStart)
    }

    // If we're mid-repeat, snap to the start of the current repeat; if already
    // at a repeat start, go back to the previous repeat's start.
    private func rewindRepeat() {
        let currentStart = max(1, (repeats - 1) * SampleData.rowsPerRepeat + 1)
        rows = rows > currentStart ? currentStart : max(0, currentStart - SampleData.rowsPerRepeat)
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
                        Text("of \(c.goal)").meta(size: 11)
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
                    Text("When you hit \(stitchGoal), the row counter advances.")
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

#Preview {
    NavigationStack { CounterScreen(projectId: "p1") }.tint(Palette.primary)
}
