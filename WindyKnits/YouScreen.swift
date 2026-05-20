import SwiftUI

struct YouScreen: View {
    private struct Row: Identifiable {
        let id: String
        let label: String
        let route: Route?
    }
    private let items: [Row] = [
        Row(id: "yarn", label: "Yarn stash", route: nil),
        Row(id: "needles", label: "Needle inventory", route: nil),
        Row(id: "library", label: "Pattern library", route: nil),
        Row(id: "services", label: "Connected services", route: nil),
        Row(id: "settings", label: "Settings", route: .settings)
    ]

    var body: some View {
        ZStack {
            Palette.cream.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("You")
                        .font(AppFont.serif(34))
                        .foregroundStyle(Palette.walnut)
                        .padding(.horizontal, 24)
                        .padding(.top, 20)

                    HStack(spacing: 14) {
                        Circle()
                            .fill(Palette.primary)
                            .frame(width: 56, height: 56)
                            .overlay(
                                Text("W")
                                    .font(AppFont.serif(22))
                                    .foregroundStyle(.white)
                            )
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Windy")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(Palette.walnut)
                            Text("3 active · 12 finished · joined 2024").meta()
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)

                    VStack(spacing: 10) {
                        ForEach(items) { item in
                            row(item)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 24)
                    .padding(.bottom, 32)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    @ViewBuilder
    private func row(_ item: Row) -> some View {
        if let route = item.route {
            NavigationLink(value: route) { rowBody(item.label) }
                .buttonStyle(.plain)
        } else {
            rowBody(item.label)
        }
    }

    private func rowBody(_ label: String) -> some View {
        SoftCard(padding: 14) {
            HStack {
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.walnut)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.walnutMute)
            }
        }
    }
}

#Preview {
    NavigationStack { YouScreen() }.tint(Palette.primary)
}
