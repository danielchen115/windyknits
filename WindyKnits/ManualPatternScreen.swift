import SwiftUI

// MARK: - Local model

/// In-progress pattern being authored by hand. Converted to a `ParsedPattern`
/// + `Project` on save so it can sit alongside imported PDFs.
struct ManualPattern {
    var title: String = ""
    var designer: String = ""
    var swatchHex: UInt32 = Palette.defaultImportedSwatchHex
    var sections: [ManualSection] = [.init(name: "Setup")]
    var activeSectionId: UUID

    // Optional details surfaced on the Overview / Materials / Notes tabs.
    var patternType: String = ""
    var size: String = ""
    var gauge: String = ""
    var yarn: String = ""
    var color: String = ""
    var needles: String = ""
    var notes: String = ""

    init() {
        let first = ManualSection(name: "Setup")
        self.sections = [first]
        self.activeSectionId = first.id
    }

    /// Builds an editable ManualPattern from an existing project. Projects
    /// without a `pattern` open in the editor with an empty section list so
    /// the user can author rows from scratch.
    static func from(_ project: Project) -> ManualPattern {
        var p = ManualPattern()
        p.title       = project.title
        p.designer    = project.designer
        p.swatchHex   = project.swatchHex
        p.patternType = project.patternType ?? ""
        p.size        = project.size ?? ""
        p.gauge       = project.gauge ?? ""
        p.yarn        = project.yarn
        p.color       = project.color
        p.needles     = project.needles
        p.notes       = project.notes ?? ""

        if let parsed = project.pattern, !parsed.rows.isEmpty {
            // Re-associate flat rows with their sections using each section's
            // rowCount. Rows that fall outside any section's range get grouped
            // into a trailing "Pattern" section so nothing is silently lost.
            var sections: [ManualSection] = []
            var cursor = 0
            for ps in parsed.sections {
                let count = ps.rowCount ?? 0
                let end   = min(cursor + count, parsed.rows.count)
                let slice = Array(parsed.rows[cursor..<end])
                cursor = end
                sections.append(ManualSection(name: ps.name, rows: slice.map(Self.toManualRow)))
            }
            if cursor < parsed.rows.count {
                let tail = Array(parsed.rows[cursor..<parsed.rows.count])
                sections.append(ManualSection(name: "Pattern", rows: tail.map(Self.toManualRow)))
            }
            if sections.isEmpty {
                sections = [ManualSection(name: "Pattern",
                                          rows: parsed.rows.map(Self.toManualRow))]
            }
            p.sections = sections
            p.activeSectionId = sections[0].id
        }
        return p
    }

    private static func toManualRow(_ pr: ParsedRow) -> ManualRow {
        ManualRow(kind: .row(
            side: pr.rs ? .RS : .WS,
            text: pr.text,
            sts: pr.sts.map(String.init) ?? ""
        ))
    }
}

struct ManualSection: Identifiable {
    let id: UUID
    var name: String
    var rows: [ManualRow]

    init(id: UUID = UUID(), name: String, rows: [ManualRow] = []) {
        self.id = id
        self.name = name
        self.rows = rows
    }

    /// Counts only knit rows — repeat-instruction cards don't get a row number.
    var knitRowCount: Int { rows.filter { !$0.isRepeat }.count }
}

struct ManualRow: Identifiable {
    enum Side: String { case RS, WS
        var toggled: Side { self == .RS ? .WS : .RS }
    }
    enum Kind {
        case row(side: Side, text: String, sts: String)
        case repeatRows(text: String)
    }
    let id: UUID
    var kind: Kind

    init(id: UUID = UUID(), kind: Kind) {
        self.id = id
        self.kind = kind
    }

    var isRepeat: Bool { if case .repeatRows = kind { return true } else { return false } }

    var side: Side {
        get { if case .row(let s, _, _) = kind { return s } else { return .RS } }
        set { if case .row(_, let t, let n) = kind { kind = .row(side: newValue, text: t, sts: n) } }
    }
    var text: String {
        get {
            switch kind {
            case .row(_, let t, _):    return t
            case .repeatRows(let t):   return t
            }
        }
        set {
            switch kind {
            case .row(let s, _, let n): kind = .row(side: s, text: newValue, sts: n)
            case .repeatRows:           kind = .repeatRows(text: newValue)
            }
        }
    }
    var sts: String {
        get { if case .row(_, _, let n) = kind { return n } else { return "" } }
        set { if case .row(let s, let t, _) = kind { kind = .row(side: s, text: t, sts: newValue) } }
    }
}

// MARK: - Screen

struct ManualPatternScreen: View {
    enum Step { case start, build, saved }

    @Environment(\.dismiss) private var dismiss
    @Environment(PatternStore.self) private var store
    @Environment(NavCoordinator.self) private var nav

    @State private var step: Step = .start
    @State private var pattern = ManualPattern()
    @State private var savedProjectId: String?

    var body: some View {
        ZStack {
            Palette.cream.ignoresSafeArea()

            VStack(spacing: 0) {
                navBar
                switch step {
                case .start:
                    ScrollView { ManualStart(pattern: $pattern, onContinue: advanceToBuild) }
                case .build:
                    ManualBuild(pattern: $pattern)
                case .saved:
                    ManualSaved(pattern: pattern,
                                onOpen: openSavedProject,
                                onKeepEditing: { step = .build })
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: Nav

    private var navBar: some View {
        HStack {
            CircleIconButton(system: "chevron.left") {
                switch step {
                case .start: dismiss()
                case .build: step = .start
                case .saved: step = .build
                }
            }
            Spacer()
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Palette.walnut)
                .lineLimit(1)
            Spacer()
            if step == .build {
                Button(action: save) {
                    Text("Done")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Palette.primary))
                }
                .buttonStyle(PressScaleStyle())
                // UI tests tap this to commit a freshly-built pattern.
                .accessibilityIdentifier("manualPattern.saveButton")
            } else {
                Color.clear.frame(width: 38, height: 38)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 14)
    }

    private var title: String {
        switch step {
        case .start: return "New pattern"
        case .build: return pattern.title.isEmpty ? "New pattern" : pattern.title
        case .saved: return "Saved"
        }
    }

    private func advanceToBuild() {
        withAnimation(.easeInOut(duration: 0.2)) { step = .build }
    }

    private func save() {
        let project = makeProject()
        store.add(project)
        savedProjectId = project.id
        withAnimation(.easeInOut(duration: 0.25)) { step = .saved }
    }

    private func openSavedProject() {
        // Pop the manual flow (and any Import screen below it) off the current
        // tab's stack and push the new project's detail. This lands the user on
        // the project they just made instead of back on the Import picker.
        guard let id = savedProjectId else { dismiss(); return }
        nav.resetTo(.project(id))
    }

    // MARK: Save mapping

    private func makeProject() -> Project {
        var rows: [ParsedRow] = []
        var sections: [ParsedSection] = []
        var n = 1
        for section in pattern.sections {
            let sectionRowCount = section.knitRowCount
            sections.append(ParsedSection(name: section.name.isEmpty ? "Section" : section.name,
                                           rowCount: sectionRowCount))
            for row in section.rows {
                switch row.kind {
                case .row(let side, let text, let sts):
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { continue }
                    rows.append(ParsedRow(n: n,
                                           rs: side == .RS,
                                           text: trimmed,
                                           sts: Int(sts.trimmingCharacters(in: .whitespaces))))
                    n += 1
                case .repeatRows(let text):
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { continue }
                    rows.append(ParsedRow(n: n, rs: true, text: trimmed, sts: nil))
                    n += 1
                }
            }
        }
        let parsed = ParsedPattern(fileName: pattern.title,
                                    pageCount: 0,
                                    fileSizeBytes: 0,
                                    sections: sections,
                                    rows: rows,
                                    abbreviations: [])
        let displayTitle = pattern.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let notesTrimmed = pattern.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        return Project(
            id: UUID().uuidString,
            title: displayTitle.isEmpty ? "Untitled pattern" : displayTitle,
            designer: pattern.designer.trimmingCharacters(in: .whitespacesAndNewlines),
            swatchHex: pattern.swatchHex,
            yarn: pattern.yarn.trimmingCharacters(in: .whitespacesAndNewlines),
            color: pattern.color.trimmingCharacters(in: .whitespacesAndNewlines),
            needles: pattern.needles.trimmingCharacters(in: .whitespacesAndNewlines),
            rowsDone: 0,
            rowsTotal: rows.count,
            lastWorked: "Just added",
            notes: notesTrimmed.isEmpty ? nil : notesTrimmed,
            pattern: parsed,
            patternType: trimToNil(pattern.patternType),
            size: trimToNil(pattern.size),
            gauge: trimToNil(pattern.gauge),
            createdAt: Date()
        )
    }

    private func trimToNil(_ s: String) -> String? {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}

// MARK: - Start step

private struct ManualStart: View {
    @Binding var pattern: ManualPattern
    var onContinue: () -> Void

    @State private var showDetails: Bool = false
    private let coverChoices: [UInt32] = [0xd49aa3, 0xc8a7c4, 0x7b8b6f, 0xc97c5d]

    private var canContinue: Bool {
        !pattern.title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("What are you making?")
                .font(AppFont.serif(26))
                .foregroundStyle(Palette.walnut)
            Text("Just a name to start. You can fill in the rest as you go.")
                .font(.system(size: 14))
                .foregroundStyle(Palette.walnutSoft)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 14) {
                FormField(label: "Pattern name", required: true) {
                    TextField("e.g. Sunrise Cowl", text: $pattern.title)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 14).padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Palette.paper)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Palette.line, lineWidth: 0.5)
                        )
                        .font(.system(size: 15))
                        .foregroundStyle(Palette.walnut)
                        // UI tests type the new pattern's title here.
                        .accessibilityIdentifier("manualPattern.nameField")
                }
                FormField(label: "Designer",
                          hint: "Optional — your name, the designer's, or leave blank.") {
                    TextField("Your name or a designer", text: $pattern.designer)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 14).padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Palette.paper)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Palette.line, lineWidth: 0.5)
                        )
                        .font(.system(size: 15))
                        .foregroundStyle(Palette.walnut)
                }
                FormField(label: "Cover", hint: "Pick a color for the swatch.") {
                    HStack(spacing: 10) {
                        ForEach(coverChoices, id: \.self) { hex in
                            Button {
                                pattern.swatchHex = hex
                            } label: {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color(hex: hex))
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .strokeBorder(pattern.swatchHex == hex
                                                          ? Palette.walnut
                                                          : Color.black.opacity(0.1),
                                                          lineWidth: pattern.swatchHex == hex ? 2 : 0.5)
                                    )
                            }
                            .buttonStyle(PressScaleStyle())
                        }
                    }
                }
            }
            .padding(.top, 24)

            detailsDisclosure
                .padding(.top, 20)

            Button(action: { if canContinue { onContinue() } }) {
                Text("Start adding instructions")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Palette.primary)
                    )
                    .opacity(canContinue ? 1 : 0.5)
            }
            .buttonStyle(PressScaleStyle())
            .disabled(!canContinue)
            // UI tests tap this to advance from start → build step.
            .accessibilityIdentifier("manualPattern.continueButton")
            .padding(.top, 28)

            Text("You can edit any of these later.")
                .font(.system(size: 12))
                .foregroundStyle(Palette.walnutMute)
                .frame(maxWidth: .infinity)
                .padding(.top, 18)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 32)
    }

    @ViewBuilder
    private var detailsDisclosure: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.22)) { showDetails.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Text("More details")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Palette.walnut)
                    Text("Optional")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Palette.walnutMute)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(Palette.creamSoft))
                    Spacer()
                    Image(systemName: showDetails ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Palette.walnutMute)
                }
                .padding(.vertical, 12)
            }
            .buttonStyle(PressScaleStyle())

            if showDetails {
                VStack(spacing: 14) {
                    FormField(label: "Pattern type",
                              hint: "e.g. Top-down raglan") {
                        plainTextInput(text: $pattern.patternType,
                                       placeholder: "Sweater, cowl, socks…")
                    }
                    FormField(label: "Size") {
                        plainTextInput(text: $pattern.size,
                                       placeholder: "S, M, 34\" bust…")
                    }
                    FormField(label: "Gauge") {
                        plainTextInput(text: $pattern.gauge,
                                       placeholder: "22 sts × 30 rows / 10cm")
                    }
                    FormField(label: "Yarn") {
                        plainTextInput(text: $pattern.yarn,
                                       placeholder: "Brand + line")
                    }
                    FormField(label: "Yarn color") {
                        plainTextInput(text: $pattern.color,
                                       placeholder: "Colorway or color name")
                    }
                    FormField(label: "Needles") {
                        plainTextInput(text: $pattern.needles,
                                       placeholder: "3.5 mm, 4 mm circular…")
                    }
                    FormField(label: "Notes",
                              hint: "Modifications, errata, anything to remember.") {
                        TextEditor(text: $pattern.notes)
                            .font(.system(size: 14))
                            .foregroundStyle(Palette.walnut)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 80)
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Palette.paper)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(Palette.line, lineWidth: 0.5)
                            )
                    }
                }
                .padding(.top, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func plainTextInput(text: Binding<String>, placeholder: String) -> some View {
        TextField(placeholder, text: text)
            .textFieldStyle(.plain)
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Palette.paper)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Palette.line, lineWidth: 0.5)
            )
            .font(.system(size: 15))
            .foregroundStyle(Palette.walnut)
    }
}

private struct FormField<Content: View>: View {
    let label: String
    var required: Bool = false
    var hint: String? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                HStack(spacing: 2) {
                    Text(label.uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(Palette.walnut)
                    if required {
                        Text("*").foregroundStyle(Palette.primary)
                            .font(.system(size: 11, weight: .bold))
                    }
                }
                Spacer()
                if let hint {
                    Text(hint)
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.walnutMute)
                        .lineLimit(1)
                }
            }
            content()
        }
    }
}

// MARK: - Build step

struct ManualBuild: View {
    @Binding var pattern: ManualPattern

    @State private var draft: String = ""
    @State private var nextSide: ManualRow.Side = .RS
    @State private var renameTarget: ManualSection?
    @State private var renameText: String = ""
    @FocusState private var inputFocused: Bool

    private var activeSectionIndex: Int {
        pattern.sections.firstIndex(where: { $0.id == pattern.activeSectionId }) ?? 0
    }
    private var activeSection: ManualSection { pattern.sections[activeSectionIndex] }

    private var showChips: Bool { inputFocused || !draft.isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            sectionTabs
            rowList
            smartBar
        }
        .alert("Rename section",
               isPresented: Binding(get: { renameTarget != nil },
                                    set: { if !$0 { renameTarget = nil } })) {
            TextField("Section name", text: $renameText)
            Button("Cancel", role: .cancel) { renameTarget = nil }
            Button("Save") { commitRename() }
        }
        .onAppear { recomputeNextSide() }
    }

    // MARK: Tabs

    private var sectionTabs: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(pattern.sections) { section in
                        sectionTab(section)
                            .id(section.id)
                    }
                    Button(action: addSection) {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Palette.walnutMute)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle().strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                                    .foregroundStyle(Palette.lineStrong)
                            )
                    }
                    .buttonStyle(PressScaleStyle())
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                .padding(.top, 2)
            }
            .onChange(of: pattern.activeSectionId) { _, new in
                withAnimation(.easeInOut(duration: 0.2)) {
                    proxy.scrollTo(new, anchor: .center)
                }
            }
        }
    }

    private func sectionTab(_ section: ManualSection) -> some View {
        let isActive = section.id == pattern.activeSectionId
        return Button {
            pattern.activeSectionId = section.id
            recomputeNextSide()
        } label: {
            HStack(spacing: 6) {
                Text(section.name)
                    .font(.system(size: 13, weight: .semibold))
                Text("\(section.knitRowCount)")
                    .font(AppFont.mono(11))
                    .foregroundStyle(isActive ? Palette.creamWarm.opacity(0.7) : Palette.walnutMute)
            }
            .foregroundStyle(isActive ? Palette.creamWarm : Palette.walnutSoft)
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(
                Capsule().fill(isActive ? Palette.walnut : Color.clear)
            )
            .overlay(
                Capsule().strokeBorder(isActive ? Palette.walnut : Palette.lineStrong,
                                       lineWidth: 1)
            )
        }
        .buttonStyle(PressScaleStyle())
        .contextMenu {
            Button("Rename") {
                renameText = section.name
                renameTarget = section
            }
            if pattern.sections.count > 1 {
                Button("Delete", role: .destructive) {
                    deleteSection(section)
                }
            }
        }
    }

    private func addSection() {
        let new = ManualSection(name: "New section")
        pattern.sections.append(new)
        pattern.activeSectionId = new.id
        recomputeNextSide()
    }

    private func deleteSection(_ section: ManualSection) {
        pattern.sections.removeAll { $0.id == section.id }
        if pattern.activeSectionId == section.id, let first = pattern.sections.first {
            pattern.activeSectionId = first.id
        }
        recomputeNextSide()
    }

    private func commitRename() {
        guard let target = renameTarget,
              let idx = pattern.sections.firstIndex(where: { $0.id == target.id }) else { return }
        let trimmed = renameText.trimmingCharacters(in: .whitespaces)
        pattern.sections[idx].name = trimmed.isEmpty ? "Section" : trimmed
        renameTarget = nil
    }

    // MARK: Row list

    @ViewBuilder
    private var rowList: some View {
        ScrollView {
            VStack(spacing: 8) {
                if activeSection.rows.isEmpty {
                    EmptySectionView(name: activeSection.name)
                        .padding(.top, 20)
                } else {
                    ForEach(Array(activeSection.rows.enumerated()), id: \.element.id) { idx, row in
                        rowView(row: row, index: idx)
                    }
                    helperButtons
                        .padding(.top, 4)
                }
                Color.clear.frame(height: 16)
            }
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private func rowView(row: ManualRow, index: Int) -> some View {
        switch row.kind {
        case .row:
            ManualRowCard(
                row: row,
                num: rowNumber(at: index),
                onSideToggle: { toggleSide(rowId: row.id) },
                onTextChange: { newText in updateRow(id: row.id) { $0.text = newText } },
                onStsChange:  { newSts  in updateRow(id: row.id) { $0.sts  = newSts } },
                onRemove: { removeRow(id: row.id) }
            )
        case .repeatRows(let text):
            HStack(spacing: 10) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(hex: 0x7b8b6f))
                Text(text)
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.walnut)
                Spacer(minLength: 0)
                Button { removeRow(id: row.id) } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Palette.walnutSoft)
                        .frame(width: 18, height: 18)
                        .background(Circle().fill(Palette.walnut.opacity(0.08)))
                }
                .buttonStyle(PressScaleStyle())
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(hex: 0x7b8b6f).opacity(0.16))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(style: StrokeStyle(lineWidth: 0.75, dash: [3, 3]))
                    .foregroundStyle(Color(hex: 0x7b8b6f))
            )
        }
    }

    private var helperButtons: some View {
        HStack(spacing: 6) {
            Button(action: insertRepeatCard) {
                helperLabel(icon: "arrow.triangle.2.circlepath", title: "Repeat rows")
            }
            .buttonStyle(PressScaleStyle())

            Button(action: { inputFocused = true }) {
                helperLabel(icon: "doc.on.clipboard", title: "Paste many")
            }
            .buttonStyle(PressScaleStyle())
        }
    }

    private func helperLabel(icon: String, title: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 11, weight: .semibold))
            Text(title).font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(Palette.walnut)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Palette.creamSoft)
        )
    }

    private func rowNumber(at index: Int) -> Int {
        // Counts knit rows from the start of the section, skipping repeat cards.
        var count = 0
        for (i, r) in activeSection.rows.enumerated() {
            if i > index { break }
            if !r.isRepeat { count += 1 }
        }
        return count
    }

    // MARK: Smart input bar

    private var smartBar: some View {
        VStack(spacing: 0) {
            if showChips { chipRow }
            inputRow
        }
        .padding(.top, 6)
        .padding(.bottom, 8)
        .background(
            Palette.creamWarm.opacity(0.96)
                .overlay(Rectangle().fill(Palette.line).frame(height: 0.5), alignment: .top)
        )
    }

    private var chipRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                Button {
                    nextSide = nextSide.toggled
                } label: {
                    Text(nextSide.rawValue)
                        .font(AppFont.mono(13, weight: .semibold))
                        .foregroundStyle(Palette.creamWarm)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Palette.walnut)
                        )
                }
                .buttonStyle(PressScaleStyle())

                ForEach(["k", "p", "k2tog", "ssk", "yo", "m1l", "m1r", "sl1"], id: \.self) { tok in
                    chipButton(tok)
                }
                ForEach([",", ";", "*"], id: \.self) { tok in
                    chipButton(tok, special: true)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
    }

    private func chipButton(_ token: String, special: Bool = false) -> some View {
        Button { insertChip(token) } label: {
            Text(token)
                .font(AppFont.mono(13, weight: .semibold))
                .foregroundStyle(Palette.walnut)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(special ? Palette.creamSoft : Palette.paper)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Palette.line, lineWidth: 0.5)
                )
        }
        .buttonStyle(PressScaleStyle())
    }

    private var inputRow: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ZStack(alignment: .topLeading) {
                if draft.isEmpty {
                    Text("Type row \(activeSection.knitRowCount + 1)…")
                        .font(AppFont.mono(14))
                        .foregroundStyle(Palette.walnutMute)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $draft)
                    .focused($inputFocused)
                    .font(AppFont.mono(14))
                    .foregroundStyle(Palette.walnut)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .frame(minHeight: 42, maxHeight: 120)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Palette.paper)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(inputFocused ? Palette.primary : Palette.lineStrong,
                                          lineWidth: inputFocused ? 1.5 : 0.5)
                    )
                    // UI tests type a row's instruction text here.
                    .accessibilityIdentifier("manualPattern.rowInput")
            }

            Button(action: commitDraft) {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(
                        Circle().fill(canSend ? Palette.primary : Palette.creamSoft)
                    )
            }
            .buttonStyle(PressScaleStyle())
            .disabled(!canSend)
            // UI tests tap this to commit the drafted row.
            .accessibilityIdentifier("manualPattern.rowSend")
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: Row mutations

    private func updateRow(id: UUID, _ mutate: (inout ManualRow) -> Void) {
        guard let secIdx = pattern.sections.firstIndex(where: { $0.id == pattern.activeSectionId }),
              let rowIdx = pattern.sections[secIdx].rows.firstIndex(where: { $0.id == id }) else { return }
        mutate(&pattern.sections[secIdx].rows[rowIdx])
    }

    private func toggleSide(rowId: UUID) {
        updateRow(id: rowId) { $0.side = $0.side.toggled }
    }

    private func removeRow(id: UUID) {
        guard let secIdx = pattern.sections.firstIndex(where: { $0.id == pattern.activeSectionId }) else { return }
        pattern.sections[secIdx].rows.removeAll { $0.id == id }
        recomputeNextSide()
    }

    private func insertChip(_ token: String) {
        // Pad with a leading space unless the previous char is whitespace and the
        // token isn't punctuation that hugs whatever came before.
        let endsInSpace = draft.last?.isWhitespace ?? true
        let isPunct = ",;*".contains(token.first ?? " ")
        let needsSpace = !endsInSpace && !isPunct
        draft += (needsSpace ? " " : "") + token
    }

    private func commitDraft() {
        let raw = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return }
        let lines = raw.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard let secIdx = pattern.sections.firstIndex(where: { $0.id == pattern.activeSectionId }) else { return }
        var side = nextSide
        for line in lines {
            let (body, hintedSide) = parseRowHint(line, fallback: side)
            side = hintedSide
            pattern.sections[secIdx].rows.append(
                ManualRow(kind: .row(side: side, text: body, sts: ""))
            )
            side = side.toggled
        }
        draft = ""
        nextSide = side
    }

    /// Strip a "Row N:" or "Row N (WS):" prefix off a pasted line.
    private func parseRowHint(_ line: String, fallback: ManualRow.Side)
        -> (body: String, side: ManualRow.Side) {
        let pattern = #"^row\s*\d+\s*(?:\(([^)]+)\))?\s*[:\.\-]\s*(.+)$"#
        guard let rx = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let m  = rx.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) else {
            return (line, fallback)
        }
        var side = fallback
        if m.range(at: 1).location != NSNotFound,
           let r = Range(m.range(at: 1), in: line) {
            side = String(line[r]).uppercased().contains("WS") ? .WS : .RS
        }
        let body: String = {
            if let r = Range(m.range(at: 2), in: line) { return String(line[r]) }
            return line
        }()
        return (body, side)
    }

    private func insertRepeatCard() {
        guard let secIdx = pattern.sections.firstIndex(where: { $0.id == pattern.activeSectionId }) else { return }
        let count = pattern.sections[secIdx].knitRowCount
        let label = count > 0 ? "Repeat rows 1–\(count), 2 times." : "Repeat previous rows, 2 times."
        pattern.sections[secIdx].rows.append(ManualRow(kind: .repeatRows(text: label)))
    }

    private func recomputeNextSide() {
        let lastKnit = activeSection.rows.reversed().first(where: { !$0.isRepeat })
        nextSide = lastKnit.map { $0.side.toggled } ?? .RS
    }
}

// MARK: - Row card

private struct ManualRowCard: View {
    let row: ManualRow
    let num: Int
    var onSideToggle: () -> Void
    var onTextChange: (String) -> Void
    var onStsChange: (String) -> Void
    var onRemove: () -> Void

    @State private var localText: String = ""
    @State private var localSts: String  = ""

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(num)")
                .font(AppFont.mono(13, weight: .bold))
                .foregroundStyle(Palette.primaryDark)
                .frame(width: 28, alignment: .trailing)
                .padding(.top, 6)

            Button(action: onSideToggle) {
                Text(row.side.rawValue)
                    .font(AppFont.mono(9, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(row.side == .RS
                                     ? Palette.primaryDark
                                     : Color(hex: 0x7b8b6f))
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(row.side == .RS
                                  ? Palette.primarySoft
                                  : Color(hex: 0x7b8b6f).opacity(0.22))
                    )
            }
            .buttonStyle(PressScaleStyle())
            .padding(.top, 6)

            TextField("Row text", text: $localText, axis: .vertical)
                .textFieldStyle(.plain)
                .font(AppFont.mono(13))
                .foregroundStyle(Palette.walnut)
                .lineLimit(1...8)
                .padding(.top, 2)
                .onChange(of: localText) { _, new in onTextChange(new) }

            TextField("sts", text: $localSts)
                .textFieldStyle(.plain)
                .font(AppFont.mono(11))
                .foregroundStyle(Palette.walnutSoft)
                .multilineTextAlignment(.center)
                .keyboardType(.numberPad)
                .frame(width: 36)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6).fill(Palette.creamSoft)
                )
                .onChange(of: localSts) { _, new in onStsChange(new) }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.paper)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Palette.line, lineWidth: 0.5)
        )
        .contextMenu {
            Button("Delete row", role: .destructive, action: onRemove)
        }
        .onAppear {
            localText = row.text
            localSts  = row.sts
        }
    }
}

// MARK: - Empty section

private struct EmptySectionView: View {
    let name: String
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 26, weight: .regular))
                .foregroundStyle(Palette.primaryDark)
                .frame(width: 64, height: 64)
                .background(RoundedRectangle(cornerRadius: 18).fill(Palette.creamWarm))
            Text("\(name) is empty.")
                .font(AppFont.serif(18))
                .foregroundStyle(Palette.walnut)
            Text("Type your first row below — Return commits it. Or paste a full pattern and we'll split it up.")
                .font(.system(size: 13))
                .foregroundStyle(Palette.walnutMute)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .frame(maxWidth: 260)
            HStack(spacing: 6) {
                Chip(text: "K2, p2, rep…", monospaced: true)
                Chip(text: "Cast on 96",   monospaced: true)
            }
        }
        .padding(.vertical, 30)
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Saved confirmation

private struct ManualSaved: View {
    let pattern: ManualPattern
    var onOpen: () -> Void
    var onKeepEditing: () -> Void

    private var totalRows: Int {
        pattern.sections.reduce(0) { $0 + $1.knitRowCount }
    }

    var body: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 32)
            ZStack {
                Circle()
                    .fill(Color(hex: 0x7b8b6f))
                    .frame(width: 96, height: 96)
                    .shadow(color: Color(hex: 0x7b8b6f).opacity(0.45),
                            radius: 18, x: 0, y: 12)
                Image(systemName: "checkmark")
                    .font(.system(size: 42, weight: .bold))
                    .foregroundStyle(.white)
            }
            Text("Pattern saved.")
                .font(AppFont.serif(28))
                .foregroundStyle(Palette.walnut)
            VStack(spacing: 4) {
                Text(pattern.title.isEmpty ? "Your pattern" : pattern.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.walnut)
                Text("\(pattern.sections.count) section\(pattern.sections.count == 1 ? "" : "s") · \(totalRows) row\(totalRows == 1 ? "" : "s") · Ready when you are.")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.walnutSoft)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)

            VStack(spacing: 8) {
                Button(action: onOpen) {
                    Text("Open project")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Palette.primary)
                        )
                }
                .buttonStyle(PressScaleStyle())
                // UI tests tap this to navigate to the newly-saved project.
                .accessibilityIdentifier("manualPattern.openProject")
                Button(action: onKeepEditing) {
                    Text("Keep editing")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Palette.walnutMute)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(PressScaleStyle())
            }
            .padding(.horizontal, 24)
            .padding(.top, 6)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    NavigationStack { ManualPatternScreen() }
        .environment(PatternStore.shared)
        .environment(NavCoordinator())
        .tint(Palette.primary)
}
