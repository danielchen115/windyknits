import SwiftUI

/// Shown the first time a non-Apple-Intelligence device imports a pattern, so
/// the user can choose between sending pattern text to Claude (for better
/// section detection) or staying on-device with the heuristic parser.
struct ConsentSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(WindyKnitsSettings.self) private var settings

    /// Called with `true` if the user agreed to use Claude. The view dismisses
    /// itself after invoking the callback.
    var onDecision: (Bool) -> Void

    @State private var showNoKeyAlert = false

    var body: some View {
        ZStack {
            Palette.cream.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 20) {
                handle

                VStack(alignment: .leading, spacing: 8) {
                    Text("Use Claude for better parsing?")
                        .font(AppFont.serif(24))
                        .foregroundStyle(Palette.walnut)
                    Text("This device doesn't have Apple Intelligence, so we can't analyze your pattern fully on-device. We can send the pattern's text to Anthropic's Claude to spot real knitting sections instead of metadata blocks.")
                        .font(.system(size: 14))
                        .foregroundStyle(Palette.walnutSoft)
                        .lineSpacing(3)
                }

                SoftCard(padding: 14) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "lock.shield")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Palette.primaryDark)
                            .frame(width: 32, height: 32)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Palette.creamSoft))
                        VStack(alignment: .leading, spacing: 4) {
                            Text("What leaves your device")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Palette.walnut)
                            Text("Section headers and short surrounding text are sent to Claude. The PDF file itself stays on your phone. You can change this any time in Settings.")
                                .font(.system(size: 12))
                                .foregroundStyle(Palette.walnutSoft)
                                .lineSpacing(2)
                        }
                    }
                }

                Spacer(minLength: 0)

                VStack(spacing: 10) {
                    PrimaryButton(title: "Use Claude") {
                        if (settings.anthropicAPIKey ?? "").isEmpty {
                            showNoKeyAlert = true
                        } else {
                            settings.cloudConsent = true
                            onDecision(true)
                            dismiss()
                        }
                    }
                    SoftButton(title: "Use basic parser", fill: true) {
                        settings.cloudConsent = false
                        onDecision(false)
                        dismiss()
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 14)
            .padding(.bottom, 28)
        }
        .alert("No API key set", isPresented: $showNoKeyAlert) {
            Button("Use basic parser for now") {
                settings.cloudConsent = false
                onDecision(false)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Add an Anthropic API key in Settings (You ▸ Settings) to enable cloud parsing.")
        }
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
    Color.clear
        .sheet(isPresented: .constant(true)) {
            ConsentSheet(onDecision: { _ in })
                .environment(WindyKnitsSettings.shared)
        }
}
