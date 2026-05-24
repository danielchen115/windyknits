import SwiftUI
import UniformTypeIdentifiers

struct ImportScreen: View {
    enum Step: Int { case pick = 0, parsing = 1, review = 2 }

    @Environment(\.dismiss) private var dismiss
    @Environment(PatternStore.self) private var store
    @Environment(WindyKnitsSettings.self) private var settings

    @State private var step: Step = .pick
    @State private var showFileImporter = false
    @State private var pickedURL: URL?
    @State private var pickError: String?

    @State private var showConsentSheet = false
    @State private var parseResult: PatternImporter.ParseResult?
    @State private var parseError: String?

    var body: some View {
        ZStack {
            Palette.cream.ignoresSafeArea()

            VStack(spacing: 0) {
                navBar
                stepDots
                ScrollView {
                    Group {
                        switch step {
                        case .pick:
                            ImportPick(error: pickError) { showFileImporter = true }
                        case .parsing:
                            ImportParsing(url: pickedURL,
                                          onParsed: handleParsed,
                                          onError: handleParseError)
                        case .review:
                            if let parseResult {
                                ImportReview(initial: parseResult, onSave: handleSave)
                            } else if let parseError {
                                ImportErrorView(message: parseError) { reset() }
                            }
                        }
                    }
                    .padding(.bottom, 32)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
        .sheet(isPresented: $showConsentSheet) {
            ConsentSheet { _ in
                // The user's decision is already persisted by ConsentSheet via
                // settings.cloudConsent. Just advance to parsing.
                advance(to: .parsing)
            }
            .presentationDetents([.medium, .large])
        }
    }

    // MARK: - State transitions

    private func reset() {
        parseResult = nil
        parseError = nil
        pickedURL = nil
        advance(to: .pick)
    }

    private func advance(to next: Step) {
        withAnimation(.easeInOut(duration: 0.25)) { step = next }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            pickError = nil
            pickedURL = url
            if shouldAskConsent() {
                showConsentSheet = true
            } else {
                advance(to: .parsing)
            }
        case .failure(let error):
            pickError = error.localizedDescription
        }
    }

    /// True when Apple Intelligence isn't available on this device AND the user
    /// hasn't previously decided whether off-device parsing is OK.
    private func shouldAskConsent() -> Bool {
        guard settings.cloudConsent == nil else { return false }
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), AppleRefiner.isAvailable {
            return false
        }
        #endif
        return true
    }

    private func handleParsed(_ result: PatternImporter.ParseResult) {
        parseResult = result
        parseError = nil
        advance(to: .review)
    }

    private func handleParseError(_ message: String) {
        parseError = message
        parseResult = nil
        advance(to: .review)
    }

    private func handleSave(_ name: String, _ designer: String,
                            _ destination: ProjectStatus) {
        guard let result = parseResult else { return }
        let project = Project(
            id: UUID().uuidString,
            title: name.trimmedOrFallback(result.name),
            designer: designer.trimmedOrFallback(result.designer),
            swatchHex: SampleData.importedSwatchHex,
            yarn: "",
            color: "",
            needles: "",
            rowsDone: 0,
            rowsTotal: result.pattern.rows.count,
            lastWorked: destination == .queue ? "Queued just now" : "Just imported",
            notes: nil,
            pattern: result.pattern,
            status: destination
        )
        store.add(project)
        dismiss()
    }

    // MARK: - Chrome

    private var title: String {
        switch step {
        case .pick:    "Import pattern"
        case .parsing: "Reading PDF"
        case .review:  parseError == nil ? "Review" : "Couldn't import"
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

// MARK: - Pick

private struct ImportPick: View {
    var error: String?
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

            if let error {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Palette.primaryDark)
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.walnut)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 14).fill(Palette.primarySoft.opacity(0.4)))
            }

            HStack(spacing: 12) {
                Rectangle().fill(Palette.line).frame(height: 0.5)
                Text("or")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.walnutMute)
                Rectangle().fill(Palette.line).frame(height: 0.5)
            }

            NavigationLink(value: Route.manualPattern) {
                HStack(spacing: 14) {
                    Image(systemName: "pencil.line")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Palette.primary))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Start from scratch")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Palette.walnut)
                        Text("Type rows by hand — no PDF needed")
                            .meta(size: 12)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Palette.primaryDark)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Palette.primarySoft.opacity(0.45))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Palette.primary.opacity(0.55), lineWidth: 0.75)
                )
            }
            .buttonStyle(PressScaleStyle())

            VStack(spacing: 10) {
                ImportSourceRow(icon: "books.vertical",
                                label: "Ravelry library",
                                sub: "Connected · 14 patterns")
                ImportSourceRow(icon: "folder",
                                label: "From Files",
                                sub: "iCloud Drive, Dropbox…",
                                action: onPick)
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
    var action: (() -> Void)? = nil

    var body: some View {
        Button {
            action?()
        } label: {
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
        .buttonStyle(PressScaleStyle())
        .disabled(action == nil)
    }
}

// MARK: - Parsing

private struct ImportParsing: View {
    let url: URL?
    var onParsed: (PatternImporter.ParseResult) -> Void
    var onError: (String) -> Void

    @Environment(WindyKnitsSettings.self) private var settings

    @State private var phase: Int = 0
    @State private var fileName: String = ""
    @State private var sizeLabel: String = ""
    @State private var detectingLabel: String = "Detecting pattern sections"

    private var phaseLabels: [String] {
        [
            "Reading pages…",
            detectingLabel,
            "Finding row instructions",
            "Resolving abbreviations"
        ]
    }

    var body: some View {
        VStack(spacing: 22) {
            SoftCard {
                VStack(spacing: 8) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 28, weight: .regular))
                        .foregroundStyle(Palette.primaryDark)
                        .frame(width: 64, height: 64)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Palette.creamSoft))
                    Text(fileName.isEmpty ? "Reading…" : fileName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Palette.walnut)
                        .padding(.top, 6)
                        .lineLimit(1)
                    Text(sizeLabel).meta()
                    BouncingDots(color: Palette.primary).padding(.top, 14)
                }
                .frame(maxWidth: .infinity)
            }

            VStack(alignment: .leading, spacing: 14) {
                ForEach(phaseLabels.indices, id: \.self) { i in
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
                        Text(phaseLabels[i])
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
        .task(id: url) {
            await runImport()
        }
    }

    private func runImport() async {
        guard let url else {
            onError("No file selected.")
            return
        }
        do {
            // Phase 0: open the document on a background task.
            let extracted = try await Task.detached(priority: .userInitiated) {
                try PatternImporter.extract(from: url)
            }.value

            await MainActor.run {
                fileName = extracted.fileName
                sizeLabel = "\(byteLabel(extracted.fileSizeBytes)) · \(extracted.pageCount) page\(extracted.pageCount == 1 ? "" : "s")"
            }

            // Resolve the best refiner the device can use. Heuristic-only on a
            // device with neither Apple Intelligence nor cloud consent — that's
            // a nil refiner and parse falls back automatically.
            let resolution = PatternLLMRefiner.resolve(settings: settings)

            // Surface the tier in the parsing animation so the user knows
            // whether an LLM is involved at all.
            await MainActor.run {
                switch resolution.expectedTier {
                case .appleIntelligence:
                    detectingLabel = "Detecting sections with Apple Intelligence"
                case .claude:
                    detectingLabel = "Detecting sections with Claude"
                case .basic:
                    detectingLabel = "Detecting pattern sections"
                }
            }

            // Tick phases 1-3 cosmetically while extract + early passes complete.
            // The "Detecting pattern sections" phase (index 1) is gated below on
            // the actual parse returning, since that's where the LLM call lives.
            for next in 1...phaseLabels.count {
                try await Task.sleep(nanoseconds: 500_000_000)
                if Task.isCancelled { return }
                if next == 2 { break }   // hold here until parse completes
                await MainActor.run { phase = next }
            }

            let result = await PatternImporter.parse(extracted,
                                                      refiner: resolution.refiner,
                                                      expectedTier: resolution.expectedTier)

            // Now finish ticking the remaining phases so the UI feels complete.
            for next in 2...phaseLabels.count {
                if Task.isCancelled { return }
                await MainActor.run { phase = next }
                try await Task.sleep(nanoseconds: 300_000_000)
            }

            if Task.isCancelled { return }
            onParsed(result)
        } catch {
            onError(error.localizedDescription)
        }
    }

    private func byteLabel(_ bytes: Int) -> String {
        let mb = Double(bytes) / 1_048_576
        if mb >= 0.1 { return String(format: "%.1f MB", mb) }
        let kb = max(1, Int((Double(bytes) / 1024).rounded()))
        return "\(kb) KB"
    }
}

// MARK: - Review

private struct ImportReview: View {
    let initial: PatternImporter.ParseResult
    var onSave: (_ name: String, _ designer: String, _ destination: ProjectStatus) -> Void

    @State private var name: String
    @State private var designer: String
    @State private var destination: ProjectStatus = .active

    init(initial: PatternImporter.ParseResult,
         onSave: @escaping (_ name: String, _ designer: String, _ destination: ProjectStatus) -> Void) {
        self.initial = initial
        self.onSave = onSave
        _name = State(initialValue: initial.name)
        _designer = State(initialValue: initial.designer)
    }

    private var pattern: ParsedPattern { initial.pattern }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Here's what we found.")
                    .font(AppFont.serif(26))
                    .foregroundStyle(Palette.walnut)
                Text(reviewSubtitle)
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.walnutSoft)
            }

            SoftCard {
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Pattern name", text: $name)
                        .font(AppFont.serif(22))
                        .foregroundStyle(Palette.walnut)
                    TextField("Designer (optional)", text: $designer)
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.walnutMute)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // File summary chip
            HStack(spacing: 10) {
                Image(systemName: "doc.text")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.walnutMute)
                Text(pattern.fileName)
                    .font(AppFont.mono(12))
                    .foregroundStyle(Palette.walnutMute)
                    .lineLimit(1)
                Spacer()
                Text("\(pattern.fileSizeLabel) · \(pattern.pagesLabel)")
                    .font(AppFont.mono(12))
                    .foregroundStyle(Palette.walnutMute)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 12).fill(Palette.creamSoft.opacity(0.5)))

            tierChip

            sectionsBlock
            abbreviationsBlock
            rowsBlock

            DestinationChooser(value: $destination)
                .padding(.top, 4)

            PrimaryButton(title: saveButtonLabel) {
                onSave(name, designer, destination)
            }
            .padding(.top, 8)
        }
        .padding(.horizontal, 24)
    }

    private var saveButtonLabel: String {
        switch destination {
        case .active:   "Save & cast on"
        case .queue:    "Save to queue"
        case .finished: "Save"
        }
    }

    private var reviewSubtitle: String {
        let bits: [String] = [
            "\(pattern.sections.count) section\(pattern.sections.count == 1 ? "" : "s")",
            "\(pattern.rows.count) row\(pattern.rows.count == 1 ? "" : "s")",
            "\(pattern.abbreviations.count) abbreviations"
        ]
        return bits.joined(separator: " · ")
    }

    private var tierChip: some View {
        let tier = initial.tier
        let tone: (foreground: Color, background: Color) = {
            switch tier {
            case .appleIntelligence, .claude:
                return (Palette.primaryDark, Palette.accent.opacity(0.18))
            case .basic(.configured):
                return (Palette.walnutMute, Palette.creamSoft.opacity(0.6))
            case .basic(.llmFailed):
                return (Palette.primaryDark, Palette.primarySoft.opacity(0.6))
            }
        }()
        return HStack(spacing: 8) {
            Image(systemName: tier.sfSymbol)
                .font(.system(size: 12, weight: .semibold))
            Text(tier.detailLabel)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .foregroundStyle(tone.foreground)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(tone.background))
    }

    @ViewBuilder
    private var sectionsBlock: some View {
        if !pattern.sections.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Sections detected").eyebrow()
                VStack(spacing: 8) {
                    ForEach(Array(pattern.sections.enumerated()), id: \.element.id) { idx, s in
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
                                if let rows = s.rowCount {
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
        } else {
            emptyDetectionCard(icon: "square.stack.3d.up",
                               title: "No sections detected",
                               body: "We couldn't spot heading-style breaks in this PDF — you'll still be able to count rows.")
        }
    }

    @ViewBuilder
    private var abbreviationsBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Abbreviations · \(pattern.abbreviations.count) found").eyebrow()
            if pattern.abbreviations.isEmpty {
                emptyDetectionCard(icon: "textformat.abc",
                                   title: "No abbreviations found",
                                   body: "We didn't recognise any knitting shorthand — odd for a pattern. You can add abbreviations after saving.")
            } else {
                SoftCard(padding: 14) {
                    FlowLayout(spacing: 8) {
                        ForEach(pattern.abbreviations, id: \.self) { a in
                            Chip(text: a, monospaced: true)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var rowsBlock: some View {
        if !pattern.rows.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("First rows").eyebrow()
                SoftCard(padding: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(pattern.rows.prefix(5)) { r in
                            HStack(alignment: .top, spacing: 10) {
                                Text("R\(r.n)")
                                    .font(AppFont.mono(12, weight: .semibold))
                                    .foregroundStyle(Palette.primaryDark)
                                    .frame(width: 32, alignment: .leading)
                                Text(r.text)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Palette.walnutSoft)
                                    .lineLimit(2)
                                Spacer(minLength: 0)
                                if let sts = r.sts {
                                    Text("\(sts)st")
                                        .font(AppFont.mono(11))
                                        .foregroundStyle(Palette.walnutMute)
                                }
                            }
                        }
                        if pattern.rows.count > 5 {
                            Text("+ \(pattern.rows.count - 5) more")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Palette.walnutMute)
                                .padding(.top, 2)
                        }
                    }
                }
            }
        }
    }

    private func emptyDetectionCard(icon: String, title: String, body: String) -> some View {
        SoftCard(padding: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Palette.walnutMute)
                    .frame(width: 32, height: 32)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Palette.creamSoft))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Palette.walnut)
                    Text(body).meta(size: 12)
                }
            }
        }
    }
}

private struct ImportErrorView: View {
    let message: String
    var onTryAgain: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("That didn't work.")
                .font(AppFont.serif(26))
                .foregroundStyle(Palette.walnut)
            SoftCard(padding: 16) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Palette.primaryDark)
                    Text(message)
                        .font(.system(size: 14))
                        .foregroundStyle(Palette.walnut)
                }
            }
            PrimaryButton(title: "Try another file", action: onTryAgain)
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - Flow layout (chips wrap onto multiple lines)

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

private extension String {
    func trimmedOrFallback(_ fallback: String) -> String {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? fallback : t
    }
}

#Preview {
    NavigationStack { ImportScreen() }
        .environment(PatternStore.shared)
        .tint(Palette.primary)
}
