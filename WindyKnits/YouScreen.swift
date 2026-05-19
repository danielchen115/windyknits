import SwiftUI

struct YouScreen: View {
    private let items = [
        "Yarn stash",
        "Needle inventory",
        "Pattern library",
        "Connected services",
        "Settings"
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
                        ForEach(items, id: \.self) { item in
                            SoftCard(padding: 14) {
                                HStack {
                                    Text(item)
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
                    .padding(.horizontal, 16)
                    .padding(.top, 24)
                    .padding(.bottom, 32)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview {
    NavigationStack { YouScreen() }.tint(Palette.primary)
}
