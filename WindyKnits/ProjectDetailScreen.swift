import SwiftUI

struct ProjectDetailScreen: View {
    let projectId: String
    @State private var tab: DetailTab = .overview
    @Environment(\.dismiss) private var dismiss

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

    private var project: Project { SampleData.project(id: projectId) }

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
                CircleIconButton(system: "ellipsis") {}
            }
            .padding(.horizontal, 16)
            .padding(.top, 56)
        }
    }

    private var title: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("In progress").eyebrow(color: Palette.primaryDark)
            Text(project.title)
                .font(AppFont.serif(34))
                .foregroundStyle(Palette.walnut)
            Text("by \(project.designer)").meta(size: 14)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, -8)
    }

    // MARK: progress

    private var progressCard: some View {
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
        .padding(.horizontal, 16)
        .padding(.top, 20)
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
            KV("Pattern type", "Top-down raglan")
            KV("Size", "S (34\" bust)")
            KV("Gauge", "22 sts × 30 rows / 10cm")
            KV("Started", "Apr 2, 2026")
            KV("Estimated finish", "Jun 14")
        }
    }

    private var materialsContent: some View {
        VStack(spacing: 16) {
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
                            Text(project.yarn)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Palette.walnut)
                            Text("\(project.color) · 4 skeins used").meta()
                        }
                        Spacer()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            SoftCard(padding: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Needles").eyebrow()
                    HStack(spacing: 10) {
                        NeedleIcon(size: 22, color: Palette.walnut)
                        Text(project.needles)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Palette.walnut)
                        Text("circular, 80cm").meta()
                        Spacer()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var notesContent: some View {
        SoftCard(padding: 16) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Your notes").eyebrow()
                Text(project.notes
                     ?? "Tap to add a note about this project — modifications, errata, anything to remember next time.")
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.walnut)
                    .lineSpacing(4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct KV: View {
    let k: String, v: String
    init(_ k: String, _ v: String) { self.k = k; self.v = v }
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(k).meta()
            Spacer()
            Text(v)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Palette.walnut)
        }
        .padding(.bottom, 14)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Palette.line).frame(height: 0.5)
        }
        .padding(.bottom, 14)
    }
}

#Preview {
    NavigationStack { ProjectDetailScreen(projectId: "p1") }.tint(Palette.primary)
}
