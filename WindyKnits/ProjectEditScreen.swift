import SwiftUI

/// Edits an existing project's title, designer, optional details, materials,
/// notes, and full instruction list. Uses the same `ManualBuild` row editor
/// that powers manual-pattern creation, so the instructions tab feels identical
/// to the creation flow.
struct ProjectEditScreen: View {
    let projectId: String

    @Environment(\.dismiss) private var dismiss
    @Environment(PatternStore.self) private var store

    @State private var pattern: ManualPattern
    @State private var tab: EditTab = .overview

    enum EditTab: Hashable, CaseIterable {
        case overview, materials, notes, instructions
        var label: String {
            switch self {
            case .overview:     return "Overview"
            case .materials:    return "Materials"
            case .notes:        return "Notes"
            case .instructions: return "Instructions"
            }
        }
    }

    init(projectId: String) {
        self.projectId = projectId
        // Navigation should always pass a real id; if the project is gone,
        // open with a blank editor and dismiss() runs from .onAppear below.
        let initial = PatternStore.shared.project(id: projectId).map(ManualPattern.from)
            ?? ManualPattern()
        _pattern = State(initialValue: initial)
    }

    var body: some View {
        ZStack {
            Palette.cream.ignoresSafeArea()

            VStack(spacing: 0) {
                navBar
                titleHeader
                segmentedTabs
                tabContent
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            if store.project(id: projectId) == nil { dismiss() }
        }
    }

    // MARK: Nav

    private var navBar: some View {
        HStack {
            CircleIconButton(system: "chevron.left") { dismiss() }
            Spacer()
            Text("Edit project")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Palette.walnut)
            Spacer()
            Button(action: save) {
                Text("Save")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Palette.primary))
            }
            .buttonStyle(PressScaleStyle())
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 14)
    }

    private var titleHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            EditField(label: "Pattern name", text: $pattern.title,
                      placeholder: "e.g. Sunrise Cowl")
            EditField(label: "Designer", text: $pattern.designer,
                      placeholder: "Optional")
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 14)
    }

    private var segmentedTabs: some View {
        HStack {
            Spacer()
            Segmented(selection: $tab,
                      options: EditTab.allCases.map { ($0, $0.label) })
            Spacer()
        }
        .padding(.bottom, 14)
    }

    // MARK: Tabs

    @ViewBuilder
    private var tabContent: some View {
        switch tab {
        case .overview:     overviewForm
        case .materials:    materialsForm
        case .notes:        notesForm
        case .instructions: instructionsEditor
        }
    }

    private var overviewForm: some View {
        ScrollView {
            VStack(spacing: 14) {
                EditField(label: "Pattern type", text: $pattern.patternType,
                          placeholder: "Sweater, cowl, socks…")
                EditField(label: "Size", text: $pattern.size,
                          placeholder: "S, M, 34\" bust…")
                EditField(label: "Gauge", text: $pattern.gauge,
                          placeholder: "22 sts × 30 rows / 10cm")
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }

    private var materialsForm: some View {
        ScrollView {
            VStack(spacing: 14) {
                EditField(label: "Yarn", text: $pattern.yarn,
                          placeholder: "Brand + line")
                EditField(label: "Yarn color", text: $pattern.color,
                          placeholder: "Colorway or color name")
                EditField(label: "Needles", text: $pattern.needles,
                          placeholder: "3.5 mm, 4 mm circular…")
                coverPicker
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }

    private var coverPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("COVER COLOR")
                .font(.system(size: 11, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(Palette.walnut)
            HStack(spacing: 8) {
                ForEach([0xd49aa3, 0xc8a7c4, 0x7b8b6f, 0xc97c5d] as [UInt32], id: \.self) { hex in
                    Button { pattern.swatchHex = hex } label: {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(hex: hex))
                            .frame(width: 44, height: 44)
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
                Spacer()
            }
        }
    }

    private var notesForm: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("NOTES")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(Palette.walnut)
                TextEditor(text: $pattern.notes)
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.walnut)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 220)
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Palette.paper)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Palette.line, lineWidth: 0.5)
                    )
                Text("Modifications, errata, anything to remember next time.")
                    .meta(size: 12)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }

    private var instructionsEditor: some View {
        ManualBuild(pattern: $pattern)
    }

    // MARK: Save

    private func save() {
        guard var project = store.project(id: projectId) else {
            dismiss()
            return
        }

        let title = pattern.title.trimmingCharacters(in: .whitespacesAndNewlines)
        project.title    = title.isEmpty ? project.title : title
        project.designer = pattern.designer.trimmingCharacters(in: .whitespacesAndNewlines)
        project.swatchHex   = pattern.swatchHex
        project.yarn        = pattern.yarn.trimmingCharacters(in: .whitespacesAndNewlines)
        project.color       = pattern.color.trimmingCharacters(in: .whitespacesAndNewlines)
        project.needles     = pattern.needles.trimmingCharacters(in: .whitespacesAndNewlines)
        let notesTrimmed    = pattern.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        project.notes       = notesTrimmed.isEmpty ? nil : notesTrimmed
        project.patternType = trimToNil(pattern.patternType)
        project.size        = trimToNil(pattern.size)
        project.gauge       = trimToNil(pattern.gauge)

        let (parsedSections, parsedRows) = flattenSections()
        let existing = project.pattern
        project.pattern = ParsedPattern(
            fileName: existing?.fileName ?? project.title,
            pageCount: existing?.pageCount ?? 0,
            fileSizeBytes: existing?.fileSizeBytes ?? 0,
            sections: parsedSections,
            rows: parsedRows,
            abbreviations: existing?.abbreviations ?? []
        )
        project.rowsTotal = parsedRows.count
        // Keep rowsDone within bounds — easy to slip past the new total when
        // shortening a pattern.
        project.rowsDone  = min(project.rowsDone, parsedRows.count)

        store.update(project)
        dismiss()
    }

    private func flattenSections() -> (sections: [ParsedSection], rows: [ParsedRow]) {
        var rows: [ParsedRow] = []
        var sections: [ParsedSection] = []
        var n = 1
        for section in pattern.sections {
            var sectionRowCount = 0
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
                    sectionRowCount += 1
                case .repeatRows(let text):
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { continue }
                    rows.append(ParsedRow(n: n, rs: true, text: trimmed, sts: nil))
                    n += 1
                    sectionRowCount += 1
                }
            }
            sections.append(ParsedSection(
                name: section.name.isEmpty ? "Section" : section.name,
                rowCount: sectionRowCount
            ))
        }
        return (sections, rows)
    }

    private func trimToNil(_ s: String) -> String? {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}

private struct EditField: View {
    let label: String
    @Binding var text: String
    var placeholder: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 11, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(Palette.walnut)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .foregroundStyle(Palette.walnut)
                .padding(.horizontal, 14).padding(.vertical, 12)
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
}

#Preview {
    NavigationStack { ProjectEditScreen(projectId: "p1") }
        .environment(PatternStore.shared)
        .environment(NavCoordinator())
        .tint(Palette.primary)
}
