import SwiftUI

struct ImportScreen: View {
    enum Step: Int { case pick = 0, parsing = 1, review = 2 }

    @Environment(\.dismiss) private var dismiss
    @State private var step: Step = .pick

    var body: some View {
        ZStack {
            Palette.cream.ignoresSafeArea()

            VStack(spacing: 0) {
                navBar
                stepDots
                ScrollView {
                    Group {
                        switch step {
                        case .pick:    ImportPick { advance(to: .parsing) }
                        case .parsing: ImportParsing { advance(to: .review) }
                        case .review:  ImportReview {
                            advance(to: .review)  // no-op for "save"; just dismisses
                            dismiss()
                        }
                        }
                    }
                    .padding(.bottom, 32)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private func advance(to next: Step) {
        withAnimation(.easeInOut(duration: 0.25)) { step = next }
    }

    private var title: String {
        switch step {
        case .pick:    "Import pattern"
        case .parsing: "Reading PDF"
        case .review:  "Review"
        }
    }

    private var navBar: some View {
        HStack {
            CircleIconButton(system: "chevron.left") {
                if step == .pick {
                    dismiss()
                } else if let prev = Step(rawValue: step.rawValue - 1) {
                    advance(to: prev)
                }
            }
            Spacer()
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Palette.walnut)
            Spacer()
            Color.clear.frame(width: 38, height: 38)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 14)
    }

    private var stepDots: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { i in
                Capsule()
                    .fill(i <= step.rawValue ? Palette.primary : Palette.creamSoft)
                    .frame(width: i == step.rawValue ? 28 : 16, height: 4)
                    .animation(.easeInOut(duration: 0.25), value: step)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 18)
    }
}

// MARK: pick

private struct ImportPick: View {
    var onPick: () -> Void
    @State private var hover = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Add a pattern")
                    .font(AppFont.serif(28))
                    .foregroundStyle(Palette.walnut)
                Text("Drop in a PDF and we'll pull out the rows, abbreviations, and stitch counts so you can knit straight from your phone.")
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.walnutSoft)
                    .lineSpacing(3)
            }

            Button(action: onPick) {
                VStack(spacing: 0) {
                    Image(systemName: "arrow.up.doc")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Palette.primaryDark)
                        .frame(width: 52, height: 52)
                        .background(Circle().fill(Palette.creamSoft))
                    Text("Drop a PDF here")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Palette.walnut)
                        .padding(.top, 14)
                    Text("or tap to choose a file").meta(size: 13)
                        .padding(.top, 4)
                }
                .padding(.vertical, 36)
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Palette.paper.opacity(0.5))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6, 5]))
                        .foregroundStyle(Palette.lineStrong)
                )
            }
            .buttonStyle(PressScaleStyle())

            HStack(spacing: 12) {
                Rectangle().fill(Palette.line).frame(height: 0.5)
                Text("or")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.walnutMute)
                Rectangle().fill(Palette.line).frame(height: 0.5)
            }

            VStack(spacing: 10) {
                ImportSourceRow(icon: "books.vertical",
                                label: "Ravelry library",
                                sub: "Connected · 14 patterns")
                ImportSourceRow(icon: "folder",
                                label: "From Files",
                                sub: "iCloud Drive, Dropbox…")
                ImportSourceRow(icon: "text.bubble",
                                label: "Paste text",
                                sub: "For shorter patterns")
            }

            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Palette.accent)
                Text("We read rows and abbreviations on-device. Your patterns never leave your phone.")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.walnutSoft)
                    .lineSpacing(3)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Palette.accent.opacity(0.16))
            )
        }
        .padding(.horizontal, 24)
    }
}

private struct ImportSourceRow: View {
    let icon: String
    let label: String
    let sub: String

    var body: some View {
        SoftCard(padding: 14) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Palette.walnutSoft)
                    .frame(width: 40, height: 40)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Palette.creamSoft))
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Palette.walnut)
                    Text(sub).meta(size: 12)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.walnutMute)
            }
        }
    }
}

// MARK: parsing

private struct ImportParsing: View {
    var onDone: () -> Void

    @State private var phase: Int = 0
    private let phases = [
        "Reading 12 pages…",
        "Detecting pattern sections",
        "Finding row instructions",
        "Resolving abbreviations"
    ]

    var body: some View {
        VStack(spacing: 22) {
            SoftCard {
                VStack(spacing: 8) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 28, weight: .regular))
                        .foregroundStyle(Palette.primaryDark)
                        .frame(width: 64, height: 64)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Palette.creamSoft))
                    Text("marigold-cardigan.pdf")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Palette.walnut)
                        .padding(.top, 6)
                    Text("2.4 MB · 12 pages").meta()
                    BouncingDots(color: Palette.primary).padding(.top, 14)
                }
                .frame(maxWidth: .infinity)
            }

            VStack(alignment: .leading, spacing: 14) {
                ForEach(phases.indices, id: \.self) { i in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .strokeBorder(
                                    i < phase ? Palette.accent : Palette.lineStrong,
                                    lineWidth: 1.5)
                            if i < phase {
                                Circle().fill(Palette.accent)
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(width: 22, height: 22)
                        Text(phases[i])
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Palette.walnutSoft)
                    }
                    .opacity(i < phase ? 1 : i == phase ? 0.85 : 0.35)
                    .animation(.easeOut(duration: 0.3), value: phase)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 24)
        .task {
            for _ in 0...phases.count {
                try? await Task.sleep(nanoseconds: 550_000_000)
                if Task.isCancelled { return }
                phase = min(phase + 1, phases.count)
                if phase == phases.count {
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    onDone()
                    return
                }
            }
        }
    }
}

// MARK: review

private struct ImportReview: View {
    var onSave: () -> Void

    @State private var name = "Marigold Cardigan"
    @State private var designer = "Petite Knit"

    private struct Section: Identifiable {
        let id = UUID()
        let name: String
        let rows: Int?
    }
    private let sections: [Section] = [
        .init(name: "Materials & gauge", rows: nil),
        .init(name: "Yoke",               rows: 48),
        .init(name: "Body",               rows: 96),
        .init(name: "Sleeves (×2)",       rows: 64),
        .init(name: "Ribbed hem",         rows: 12)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Here's what we found.")
                    .font(AppFont.serif(26))
                    .foregroundStyle(Palette.walnut)
                Text("Tap any section to peek inside or rename.")
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.walnutSoft)
            }

            SoftCard {
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Pattern name", text: $name)
                        .font(AppFont.serif(22))
                        .foregroundStyle(Palette.walnut)
                    TextField("Designer", text: $designer)
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.walnutMute)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Sections detected").eyebrow()
                VStack(spacing: 8) {
                    ForEach(Array(sections.enumerated()), id: \.element.id) { idx, s in
                        SoftCard(padding: 12) {
                            HStack(spacing: 12) {
                                Text("\(idx + 1)")
                                    .font(AppFont.mono(13, weight: .semibold))
                                    .foregroundStyle(Palette.primaryDark)
                                    .frame(width: 30, height: 30)
                                    .background(RoundedRectangle(cornerRadius: 8).fill(Palette.creamSoft))
                                Text(s.name)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Palette.walnut)
                                Spacer()
                                if let rows = s.rows {
                                    Text("\(rows) rows")
                                        .font(AppFont.mono(12))
                                        .foregroundStyle(Palette.walnutMute)
                                }
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Palette.walnutMute)
                            }
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Abbreviations · 14 found").eyebrow()
                SoftCard(padding: 14) {
                    FlowLayout(spacing: 8) {
                        ForEach(SampleData.abbreviationChips, id: \.self) { a in
                            Chip(text: a, monospaced: true)
                        }
                    }
                }
            }

            PrimaryButton(title: "Save to projects", action: onSave)
                .padding(.top, 8)
        }
        .padding(.horizontal, 24)
    }
}

// Simple flow-layout (chips wrap onto multiple lines).
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, lineH: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > maxW {
                x = 0
                y += lineH + spacing
                lineH = 0
            }
            x += s.width + spacing
            lineH = max(lineH, s.height)
        }
        return CGSize(width: maxW.isFinite ? maxW : x,
                      height: y + lineH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxW = bounds.width
        var x: CGFloat = bounds.minX, y: CGFloat = bounds.minY, lineH: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x - bounds.minX + s.width > maxW {
                x = bounds.minX
                y += lineH + spacing
                lineH = 0
            }
            v.place(at: CGPoint(x: x, y: y),
                    proposal: ProposedViewSize(s))
            x += s.width + spacing
            lineH = max(lineH, s.height)
        }
    }
}

#Preview {
    NavigationStack { ImportScreen() }.tint(Palette.primary)
}
