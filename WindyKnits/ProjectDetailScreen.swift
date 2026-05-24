import SwiftUI

struct ProjectDetailScreen: View {
    let projectId: String
    @State private var tab: DetailTab = .overview
    @State private var statusSheetOpen = false
    @State private var deleteSheetOpen = false
    @Environment(\.dismiss) private var dismiss
    @Environment(PatternStore.self) private var store

    enum DetailTab: Hashable, CaseIterable {
        case overview, materials, notes
        var label: String {
            switch self {
            case .overview:  return "Overview"
            case .materials: return "Materials"
            case .notes:     return "Notes"
            }
        }
    }

    private var project: Project {
        store.project(id: projectId) ?? SampleData.project(id: projectId)
    }

    var body: some View {
        ZStack {
            Palette.cream.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    hero
                    title
                    progressCard
                    segmentedTabs
                    tabContent
                }
                .padding(.bottom, 40)
            }
            .ignoresSafeArea(edges: .top)
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $statusSheetOpen) {
            StatusSheet(
                projectTitle: project.title,
                status: project.status,
                onMove: { next in
                    statusSheetOpen = false
                    guard next != project.status else { return }
                    store.setStatus(project.id, to: next)
                },
                onDelete: {
                    statusSheetOpen = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        deleteSheetOpen = true
                    }
                }
            )
        }
        .sheet(isPresented: $deleteSheetOpen) {
            DeleteConfirmSheet(
                projectTitle: project.title,
                onCancel: { deleteSheetOpen = false },
                onConfirm: {
                    store.delete(project.id)
                    deleteSheetOpen = false
                    // Pop back to the library — there's no project here anymore.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        dismiss()
                    }
                }
            )
        }
    }

    // A direct binding to the project's `notes` field — keystroke-driven so
    // there's no manual lifecycle (FocusState + onAppear) to coordinate.
    private var notesBinding: Binding<String> {
        Binding(
            get: { project.notes ?? "" },
            set: { newValue in
                var updated = project
                updated.notes = newValue.isEmpty ? nil : newValue
                store.update(updated)
            }
        )
    }

    // MARK: hero

    private var hero: some View {
        ZStack(alignment: .top) {
            PhotoPlaceholder(label: "project photo", radius: 0, tint: project.swatch)
                .frame(height: 320)
                .overlay(alignment: .bottom) {
                    LinearGradient(
                        colors: [.clear, Palette.cream],
                        startPoint: .top, endPoint: .bottom)
                        .frame(height: 90)
                }

            HStack {
                CircleIconButton(system: "chevron.left") { dismiss() }
                Spacer()
                NavigationLink(value: Route.editProject(projectId)) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Edit")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(Palette.walnut)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Palette.paper.opacity(0.85)))
                    .overlay(Capsule().strokeBorder(Palette.line, lineWidth: 0.5))
                }
                .buttonStyle(PressScaleStyle())
                CircleIconButton(system: "ellipsis") { statusSheetOpen = true }
                    .padding(.leading, 6)
            }
            .padding(.horizontal, 16)
            .padding(.top, 56)
        }
    }

    private var title: some View {
        VStack(alignment: .leading, spacing: 4) {
            StatusBadge(status: project.status, clickable: true) {
                statusSheetOpen = true
            }
            Text(project.title)
                .font(AppFont.serif(34))
                .foregroundStyle(Palette.walnut)
                .padding(.top, 4)
            if !project.designer.isEmpty {
                Text("by \(project.designer)").meta(size: 14)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, -8)
    }

    // MARK: progress (status-specific)

    @ViewBuilder
    private var progressCard: some View {
        Group {
            switch project.status {
            case .active:   activeCard
            case .queue:    queueCard
            case .finished: finishedCard
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
    }

    private var activeCard: some View {
        SoftCard {
            VStack(spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Progress").eyebrow()
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("\(project.rowsDone)")
                                .font(AppFont.serif(38))
                                .foregroundStyle(Palette.primaryDark)
                                .monospacedDigit()
                            Text("of \(project.rowsTotal) rows").meta()
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Last worked").eyebrow()
                        Text(project.lastWorked)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Palette.walnut)
                    }
                }
                ProgressBar(value: project.progress).padding(.top, 14)

                HStack(spacing: 10) {
                    NavigationLink(value: Route.pattern(project.id)) {
                        Text("Open pattern")
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

                    NavigationLink(value: Route.counter(project.id)) {
                        Text("Counter")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Palette.walnut)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Palette.creamSoft)
                            )
                    }
                    .buttonStyle(PressScaleStyle())
                }
                .padding(.top, 16)
            }
        }
    }

    private var queueCard: some View {
        SoftCard {
            VStack(alignment: .leading, spacing: 0) {
                Text("In your queue").eyebrow()
                Text(queueBlurb)
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.walnutSoft)
                    .lineSpacing(3)
                    .padding(.top, 8)

                HStack(spacing: 10) {
                    Button {
                        store.setStatus(project.id, to: .active)
                    } label: {
                        HStack(spacing: 8) {
                            NeedleIcon(size: 15, color: .white)
                            Text("Cast on")
                        }
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

                    NavigationLink(value: Route.pattern(project.id)) {
                        Text("Preview pattern")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Palette.walnut)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Palette.creamSoft)
                            )
                    }
                    .buttonStyle(PressScaleStyle())
                }
                .padding(.top, 16)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var queueBlurb: String {
        let weeks = project.estWeeks ?? 4
        return "You haven't cast on yet. Estimated \(weeks) weeks of evenings once you start."
    }

    private var finishedCard: some View {
        SoftCard {
            VStack(spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Finished").eyebrow(color: Palette.accent)
                        Text(project.finishedOn ?? "—")
                            .font(AppFont.serif(24))
                            .foregroundStyle(Palette.walnut)
                            .padding(.top, 4)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Took").eyebrow()
                        Text("\(project.daysToFinish ?? 0) days")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Palette.walnut)
                    }
                }
                ProgressBar(value: 1, color: Palette.accent)
                    .padding(.top, 14)

                HStack(spacing: 10) {
                    Button {
                        store.setStatus(project.id, to: .queue)
                    } label: {
                        Text("Knit again")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Palette.walnut)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Palette.creamSoft)
                            )
                    }
                    .buttonStyle(PressScaleStyle())

                    NavigationLink(value: Route.pattern(project.id)) {
                        Text("Open pattern")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Palette.walnut)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Palette.creamSoft)
                            )
                    }
                    .buttonStyle(PressScaleStyle())
                }
                .padding(.top, 16)
            }
        }
    }

    private var segmentedTabs: some View {
        HStack {
            Spacer()
            Segmented(selection: $tab,
                      options: DetailTab.allCases.map { ($0, $0.label) })
            Spacer()
        }
        .padding(.top, 20)
    }

    @ViewBuilder
    private var tabContent: some View {
        Group {
            switch tab {
            case .overview:  overviewContent
            case .materials: materialsContent
            case .notes:     notesContent
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var overviewContent: some View {
        VStack(spacing: 0) {
            KV("Pattern type", project.patternType)
            KV("Size", project.size)
            KV("Gauge", project.gauge)
            KV("Started", startedLabel)
        }
    }

    private var startedLabel: String? {
        guard let created = project.createdAt else { return nil }
        let f = DateFormatter()
        f.dateStyle = .medium
        return f.string(from: created)
    }

    @ViewBuilder
    private var materialsContent: some View {
        if !project.yarn.isEmpty || !project.color.isEmpty || !project.needles.isEmpty {
            VStack(spacing: 16) {
                if !project.yarn.isEmpty || !project.color.isEmpty {
                    SoftCard(padding: 16) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Yarn").eyebrow()
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(project.swatch)
                                    .frame(width: 44, height: 44)
                                    .overlay(Circle().strokeBorder(.black.opacity(0.06)))
                                    .overlay(
                                        Circle().fill(
                                            LinearGradient(
                                                colors: [.clear, .black.opacity(0.10)],
                                                startPoint: .top, endPoint: .bottom)
                                        )
                                    )
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(project.yarn.isEmpty ? "Yarn" : project.yarn)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(Palette.walnut)
                                    if !project.color.isEmpty {
                                        Text(project.color).meta()
                                    }
                                }
                                Spacer()
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                if !project.needles.isEmpty {
                    SoftCard(padding: 16) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Needles").eyebrow()
                            HStack(spacing: 10) {
                                NeedleIcon(size: 22, color: Palette.walnut)
                                Text(project.needles)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Palette.walnut)
                                Spacer()
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        } else {
            emptyDetailHint("No materials yet",
                            "Add yarn, color, or needles to keep them with this project.")
        }
    }

    @ViewBuilder
    private var notesContent: some View {
        SoftCard(padding: 16) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Your notes").eyebrow()
                ZStack(alignment: .topLeading) {
                    if (project.notes ?? "").isEmpty {
                        Text("Tap to add a note about this project — modifications, errata, anything to remember next time.")
                            .font(.system(size: 14))
                            .foregroundStyle(Palette.walnutMute)
                            .lineSpacing(4)
                            .padding(.top, 8)
                            .padding(.leading, 5)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: notesBinding)
                        .font(.system(size: 14))
                        .foregroundStyle(Palette.walnut)
                        .scrollContentBackground(.hidden)
                        .lineSpacing(4)
                        .frame(minHeight: 110)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func emptyDetailHint(_ title: String, _ body: String) -> some View {
        SoftCard(padding: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.walnut)
                Text(body)
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.walnutMute)
                    .lineSpacing(3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct KV: View {
    let k: String, v: String?
    init(_ k: String, _ v: String?) { self.k = k; self.v = v }
    private var displayValue: String {
        let trimmed = (v ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "—" : trimmed
    }
    private var isSet: Bool {
        !(v ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(k).meta()
            Spacer()
            Text(displayValue)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(isSet ? Palette.walnut : Palette.walnutMute)
        }
        .padding(.bottom, 14)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Palette.line).frame(height: 0.5)
        }
        .padding(.bottom, 14)
    }
}

#Preview {
    NavigationStack { ProjectDetailScreen(projectId: "p1") }
        .environment(PatternStore.shared)
        .tint(Palette.primary)
}
