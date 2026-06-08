import SwiftUI

/// One-shot sheet that asks the user to type a name when Sign in with Apple
/// didn't deliver one. SIWA returns `fullName` only on the very first sign-in
/// for a given Apple ID + app pair — any re-sign-in (including after our
/// `deleteAccount` flow) lands with `displayName == nil`, and without this
/// prompt the user would have to discover the editable field in Settings to
/// fix the empty "Hello." greeting.
///
/// Presentation is gated on `UserAccount.needsNameEntry`, which `adopt(_:)`
/// flips on at sign-in when no name made it through. Dismissing the sheet
/// (Save, Skip, or swipe-down) clears the flag for this session — we never
/// re-prompt on launch because the in-memory flag doesn't persist.
struct NameEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(UserAccount.self) private var account

    @State private var name: String = ""
    @FocusState private var nameFocused: Bool

    var body: some View {
        ZStack {
            Palette.cream.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 20) {
                handle

                VStack(alignment: .leading, spacing: 8) {
                    Text("What should we call you?")
                        .font(AppFont.serif(26))
                        .foregroundStyle(Palette.walnut)
                    Text("Apple didn't share your name with WindyKnits this time. Type a name to personalize the app — you can change it later in Settings → Account.")
                        .font(.system(size: 14))
                        .foregroundStyle(Palette.walnutSoft)
                        .lineSpacing(3)
                }

                SoftCard(padding: 14) {
                    TextField("Your name", text: $name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Palette.walnut)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .focused($nameFocused)
                        .onSubmit(save)
                }

                Spacer(minLength: 0)

                VStack(spacing: 10) {
                    PrimaryButton(title: "Save", action: save)
                        .opacity(trimmedName.isEmpty ? 0.5 : 1)
                        .disabled(trimmedName.isEmpty)
                    Button("Skip for now") {
                        account.needsNameEntry = false
                        dismiss()
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.walnutSoft)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 14)
            .padding(.bottom, 28)
        }
        .onAppear { nameFocused = true }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func save() {
        let value = trimmedName
        guard !value.isEmpty else { return }
        account.updateDisplayName(value)
        dismiss()
    }

    private var handle: some View {
        Capsule()
            .fill(Palette.lineStrong)
            .frame(width: 36, height: 5)
            .frame(maxWidth: .infinity)
            .padding(.top, 6)
    }
}

#Preview {
    let account = UserAccount()
    account.adopt(.init(userID: "preview", displayName: nil, email: nil))
    return Color.clear
        .sheet(isPresented: .constant(true)) {
            NameEntrySheet()
                .environment(account)
        }
}
