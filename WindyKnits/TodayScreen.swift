import SwiftUI

struct TodayScreen: View {
    @Binding var path: NavigationPath
    var switchTab: (AppTab) -> Void = { _ in }

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

    private var active: Project { SampleData.projects[0] }

    var body: some View {
        ZStack {
            Palette.cream.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    greeting
                    activeCard
                    statsRow
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
            Text("Hello, Windy.")
                .font(AppFont.serif(34))
                .foregroundStyle(Palette.walnut)
            Text("Three rows left until the next chart repeat.")
                .font(.system(size: 15))
                .foregroundStyle(Palette.walnutSoft)
                .padding(.top, 2)
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 18)
    }

    // MARK: currently knitting

    private var activeCard: some View {
        // Two tap zones inside one card. Nesting NavigationLinks (one for the
        // card, two for the inner buttons) silently swallows the inner taps in
        // SwiftUI, so the card-tap is its own Button and the inner buttons are
        // siblings — each appends its own route to the navigation path.
        SoftCard {
            VStack(alignment: .leading, spacing: 0) {
                Button { path.append(Route.project(active.id)) } label: {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(alignment: .top, spacing: 16) {
                            PhotoPlaceholder(label: "photo", tint: active.swatch)
                                .frame(width: 86, height: 86)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Currently knitting").eyebrow(color: Palette.primaryDark)
                                Text(active.title)
                                    .font(AppFont.serif(22))
                                    .foregroundStyle(Palette.walnut)
                                    .padding(.top, 2)
                                Text(active.designer).meta()
                            }
                            Spacer(minLength: 0)
                        }

                        HStack(alignment: .firstTextBaseline) {
                            Text("Row \(Text("\(active.rowsDone)").foregroundStyle(Palette.primaryDark).fontWeight(.semibold)) / \(active.rowsTotal)")
                                .foregroundStyle(Palette.walnutSoft)
                                .font(AppFont.mono(13))
                            Spacer()
                            Text(active.percentLabel)
                                .font(AppFont.mono(12))
                                .foregroundStyle(Palette.walnutMute)
                        }
                        .padding(.top, 18)

                        ProgressBar(value: active.progress)
                            .padding(.top, 8)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                HStack(spacing: 10) {
                    Button { path.append(Route.pattern(active.id)) } label: {
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

                    Button { path.append(Route.counter(active.id)) } label: {
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
    }

    // MARK: stats

    private var statsRow: some View {
        HStack(spacing: 10) {
            StatTile(label: "This week", value: "142", unit: "rows")
            StatTile(label: "Time today", value: "38", unit: "min")
            StatTile(label: "Days knit", value: "84", unit: "days")
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
        .padding(.bottom, 12)
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
                ForEach(SampleData.projects.dropFirst()) { p in
                    NavigationLink(value: Route.project(p.id)) {
                        ProjectRow(project: p)
                    }
                    .buttonStyle(.plain)
                }
                NavigationLink(value: Route.importPDF) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                        Text("Import a pattern PDF")
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
    NavigationStack { TodayScreen() }.tint(Palette.primary)
}
