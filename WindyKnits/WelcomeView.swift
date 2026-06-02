import AuthenticationServices
import SwiftUI

/// First-launch / signed-out gate. Rendered by `WindyKnitsApp` whenever
/// `UserAccount.shared.isSignedIn == false`. Sign in with Apple is the only
/// path forward — there's no skip — so by the time the tab bar appears
/// downstream, `account.displayName` is always populated.
struct WelcomeView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Palette.cream.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 60)

                NeedleIcon(size: 56, color: Palette.primaryDark)
                    .padding(.bottom, 28)

                Text("WindyKnits")
                    .font(AppFont.serif(42))
                    .foregroundStyle(Palette.walnut)

                Text("Your knitting, counted.")
                    .font(.system(size: 16))
                    .foregroundStyle(Palette.walnutSoft)
                    .padding(.top, 6)

                Spacer()

                VStack(spacing: 14) {
                    SignInWithAppleButton(
                        .signIn,
                        onRequest: { request in
                            request.requestedScopes = [.fullName, .email]
                        },
                        onCompletion: handleCompletion
                    )
                    .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                    .frame(height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 13))
                            .foregroundStyle(Palette.primaryDark)
                            .multilineTextAlignment(.center)
                            .transition(.opacity)
                    }

                    Text("Sign in stays on this device. Your name and email aren't sent anywhere.")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.walnutMute)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                        .padding(.top, 6)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
        }
    }

    private func handleCompletion(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential else {
                withAnimation { errorMessage = "Unexpected sign-in response. Please try again." }
                return
            }
            withAnimation { errorMessage = nil }
            UserAccount.shared.adopt(.init(credential: credential))

        case .failure(let error):
            // ASAuthorizationError.canceled is the user tapping Cancel —
            // not really an "error" worth alarming about. Stay quiet so
            // the button is still there to retry.
            if let asError = error as? ASAuthorizationError, asError.code == .canceled {
                return
            }
            withAnimation {
                errorMessage = friendlyMessage(for: error)
            }
        }
    }

    private func friendlyMessage(for error: Error) -> String {
        if let asError = error as? ASAuthorizationError, asError.code == .notHandled {
            return "iOS couldn't complete the sign-in. Check your network and try again."
        }
        return "Sign in didn't go through. Please try again."
    }
}

#Preview {
    WelcomeView()
}
