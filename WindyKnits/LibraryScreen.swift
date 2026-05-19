import SwiftUI

struct LibraryScreen: View {
    enum Filter: Hashable, CaseIterable { case active, queue, finished
        var label: String {
            switch self {
            case .active:   return "In progress"
            case .queue:    return "Queue"
            case .finished: return "Finished"
            }
        }
    }

    @State private var filter: Filter = .active

    var body: some View {
        ZStack {
            Palette.cream.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    filterRow
                    list
                }
                .padding(.bottom, 32)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        HStack(alignment: .center) {
            Text("Projects")
                .font(AppFont.serif(34))
                .foregroundStyle(Palette.walnut)
            Spacer()
            NavigationLink(value: Route.importPDF) {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Palette.primary))
            }
            .buttonStyle(PressScaleStyle())
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 8)
    }

    private var filterRow: some View {
        Segmented(
            selection: $filter,
            options: Filter.allCases.map { ($0, $0.label) }
        )
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var list: some View {
        VStack(spacing: 12) {
            ForEach(SampleData.projects) { p in
                NavigationLink(value: Route.project(p.id)) {
                    LibraryCard(project: p)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}

private struct LibraryCard: View {
    let project: Project

    var body: some View {
        SoftCard(padding: 14) {
            HStack(spacing: 14) {
                PhotoPlaceholder(label: "photo", radius: 12, tint: project.swatch)
                    .frame(width: 72, height: 88)
                VStack(alignment: .leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(project.title)
                            .font(AppFont.serif(17))
                            .foregroundStyle(Palette.walnut)
                        Text(project.designer).meta()
                    }
                    Spacer(minLength: 0)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("\(project.rowsDone)/\(project.rowsTotal) rows")
                                .font(AppFont.mono(11))
                                .foregroundStyle(Palette.walnutMute)
                            Spacer()
                            Text(project.lastWorked).meta(size: 11)
                        }
                        ProgressBar(value: project.progress)
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
    }
}

#Preview {
    NavigationStack { LibraryScreen() }.tint(Palette.primary)
}
