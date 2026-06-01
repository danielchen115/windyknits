import SwiftUI

struct SettingsScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(WindyKnitsSettings.self) private var settings

    @State private var keyField: String = ""
    @State private var didLoadKey = false
    @State private var keyHidden: Bool = true
    #if DEBUG
    @State private var showWipeConfirm = false
    @State private var devToast: String?
    #endif

    var body: some View {
        ZStack {
            Palette.cream.ignoresSafeArea()

            VStack(spacing: 0) {
                navBar
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        intro
                        keySection
                        cloudSection
                        resetSection
                        #if DEBUG
                        devSection
                        #endif
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                }
            }

            #if DEBUG
            if let devToast {
                VStack {
                    Spacer()
                    Text(devToast)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(Palette.walnut.opacity(0.92)))
                        .padding(.bottom, 24)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            #endif
        }
        #if DEBUG
        .alert("Wipe all data?",
               isPresented: $showWipeConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Wipe", role: .destructive) {
                DevTools.wipeAllData()
                flashToast("All project + counter data cleared.")
            }
        } message: {
            Text("Removes every project and resets every counter. Your API key in Keychain is preserved.")
        }
        #endif
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            // Prime the field from Keychain exactly once so the user can edit
            // an existing key rather than retyping it.
            if !didLoadKey {
                keyField = settings.anthropicAPIKey ?? ""
                didLoadKey = true
            }
        }
    }

    private var navBar: some View {
        HStack {
            CircleIconButton(system: "chevron.left") { dismiss() }
            Spacer()
            Text("Settings")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Palette.walnut)
            Spacer()
            Color.clear.frame(width: 38, height: 38)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 14)
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Pattern parsing")
                .font(AppFont.serif(26))
                .foregroundStyle(Palette.walnut)
            Text("On supported devices we parse patterns with Apple Intelligence — fully on-device. For older devices, you can opt in to using Anthropic's Claude instead.")
                .font(.system(size: 13))
                .foregroundStyle(Palette.walnutSoft)
                .lineSpacing(3)
        }
        .padding(.top, 6)
    }

    private var keySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Anthropic API key").eyebrow()
            SoftCard(padding: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        Group {
                            if keyHidden {
                                SecureField("sk-ant-…", text: $keyField)
                            } else {
                                TextField("sk-ant-…", text: $keyField)
                            }
                        }
                        .font(AppFont.mono(13))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .foregroundStyle(Palette.walnut)

                        Button {
                            keyHidden.toggle()
                        } label: {
                            Image(systemName: keyHidden ? "eye" : "eye.slash")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Palette.walnutMute)
                        }
                    }

                    HStack {
                        Text("Stored in your iOS Keychain.").meta(size: 11)
                        Spacer()
                        Button("Save") {
                            let trimmed = keyField.trimmingCharacters(in: .whitespacesAndNewlines)
                            settings.anthropicAPIKey = trimmed.isEmpty ? nil : trimmed
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Palette.primaryDark)
                        .disabled(keyField == (settings.anthropicAPIKey ?? ""))
                    }
                }
            }
        }
    }

    private var cloudSection: some View {
        @Bindable var bindable = settings
        return VStack(alignment: .leading, spacing: 10) {
            Text("Cloud parsing").eyebrow()
            SoftCard(padding: 14) {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle(isOn: Binding(
                        get: { settings.cloudConsent == true },
                        set: { settings.cloudConsent = $0 }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Send pattern text to Claude")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Palette.walnut)
                            Text(toggleStatus)
                                .font(.system(size: 12))
                                .foregroundStyle(Palette.walnutSoft)
                        }
                    }
                    .tint(Palette.primary)
                    .disabled((settings.anthropicAPIKey ?? "").isEmpty)
                }
            }
        }
    }

    private var toggleStatus: String {
        if (settings.anthropicAPIKey ?? "").isEmpty {
            return "Add an API key above to enable."
        }
        if settings.cloudConsent == true {
            return "Pattern headers leave your device."
        }
        return "Patterns are parsed locally with the basic parser."
    }

    private var resetSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Reset").eyebrow()
            Button {
                settings.resetCloudConsent()
            } label: {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Forget cloud parsing decision")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Palette.walnut)
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 12).fill(Palette.creamSoft))
            }
            .buttonStyle(PressScaleStyle())
            Text("You'll be asked again on the next import.").meta(size: 11)
        }
    }

    #if DEBUG
    /// Surfaces seed/wipe shortcuts on Debug builds only. Stripped from
    /// Release entirely via `#if DEBUG`.
    private var devSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Developer").eyebrow()
            SoftCard(padding: 14) {
                VStack(spacing: 10) {
                    Button {
                        DevTools.seedSampleProjects()
                        flashToast("Loaded \(SampleData.projects.count) sample projects.")
                    } label: {
                        devRow(icon: "tray.and.arrow.down",
                               label: "Load sample projects")
                    }
                    .buttonStyle(PressScaleStyle())

                    Button { showWipeConfirm = true } label: {
                        devRow(icon: "trash",
                               label: "Wipe all data",
                               tint: .red)
                    }
                    .buttonStyle(PressScaleStyle())
                }
            }
            Text("Debug builds only — not shipped to the App Store.")
                .meta(size: 11)
        }
    }

    private func devRow(icon: String, label: String, tint: Color = Palette.walnut) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 22)
            Text(label)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Palette.walnutMute)
        }
        .contentShape(Rectangle())
    }

    private func flashToast(_ message: String) {
        withAnimation(.easeOut(duration: 0.2)) { devToast = message }
        Task {
            try? await Task.sleep(for: .seconds(1.8))
            withAnimation(.easeIn(duration: 0.25)) { devToast = nil }
        }
    }
    #endif
}

#Preview {
    NavigationStack { SettingsScreen() }
        .environment(WindyKnitsSettings.shared)
        .tint(Palette.primary)
}
