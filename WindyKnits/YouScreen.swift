import SwiftUI

/// "You" tab — minimal profile + Settings entry point. The name and avatar
/// initial come from `UserAccount.displayName`, which was captured during
/// Sign in with Apple at first launch — the app's root view enforces that
/// gate, so `displayName` is always populated by the time this renders.
/// Project counts come straight from `PatternStore` so the meta line stays
/// honest as projects are added / finished.
struct YouScreen: View {
    @Environment(PatternStore.self) private var store
    @Environment(UserAccount.self) private var account

    var body: some View {
        ZStack {
            Palette.cream.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(title)
                        .font(AppFont.serif(34))
                        .foregroundStyle(Palette.walnut)
                        .padding(.horizontal, 24)
                        .padding(.top, 20)

                    profileBlock
                        .padding(.horizontal, 24)
                        .padding(.top, 16)

                    NavigationLink(value: Route.settings) {
                        SoftCard(padding: 14) {
                            HStack {
                                Text("Settings")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Palette.walnut)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Palette.walnutMute)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.top, 24)
                    .padding(.bottom, 32)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var profileBlock: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(Palette.primary)
                .frame(width: 56, height: 56)
                .overlay(
                    Text(avatarInitial)
                        .font(AppFont.serif(22))
                        .foregroundStyle(.white)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(account.displayName ?? "")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Palette.walnut)
                Text(metaLine).meta()
            }
            Spacer()
        }
    }

    /// The page heading prefers the user's display name when set, falling
    /// back to a generic "You" only when neither Apple nor the user has
    /// supplied one. Same source of truth as the greeting on Today.
    private var title: String {
        if let name = account.displayName, !name.isEmpty {
            return name
        }
        return "You"
    }

    private var avatarInitial: String {
        guard let first = account.displayName?.first else { return "" }
        return String(first).uppercased()
    }

    /// "<n> active · <m> finished" — empty-state honest: shows 0/0 when the
    /// store is empty, updates live as projects move statuses.
    private var metaLine: String {
        let counts = store.counts()
        let active = counts[.active] ?? 0
        let finished = counts[.finished] ?? 0
        return "\(active) active · \(finished) finished"
    }
}

#Preview {
    let account = UserAccount()
    account.adopt(.init(userID: "preview", displayName: "Windy", email: "windy@example.com"))
    return NavigationStack { YouScreen() }
        .environment(PatternStore.shared)
        .environment(account)
        .tint(Palette.primary)
}
