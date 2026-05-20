import SwiftUI

struct PatternViewerScreen: View {
    let projectId: String

    @Environment(\.dismiss) private var dismiss
    // Shared with CounterScreen via the same AppStorage key — advancing in
    // either screen propagates to the other.
    @AppStorage private var current: Int
    @State private var voice: Bool = false
    @State private var tappedAbbr: TappedAbbr?

    init(projectId: String) {
        self.projectId = projectId
        _current = AppStorage(wrappedValue: 5, "counter.\(projectId).rows")
    }

    private var rows: [PatternRow] { SampleData.pattern }

    // The chart is `rowsPerRepeat` rows that tile vertically. UI shows the
    // chart cycle and tracks the user's position *within* the current repeat,
    // so absolute row 17 displays as "chart row 5 of 12, repeat 2 of 4".
    private var rowInRepeat: Int {
        let c = max(current, 1)
        return ((c - 1) % SampleData.rowsPerRepeat) + 1
    }
    private var repeatNumber: Int {
        let c = max(current, 1)
        return ((c - 1) / SampleData.rowsPerRepeat) + 1
    }
    private var totalRepeats: Int {
        max(1, SampleData.patternTotalRows / SampleData.rowsPerRepeat)
    }
    private var sectionComplete: Bool {
        current >= SampleData.patternTotalRows
    }
    private var currentRow: PatternRow? { rows.first { $0.n == rowInRepeat } }

    struct TappedAbbr: Identifiable {
        let id = UUID()
        let abbr: String
        let definition: String?
    }

    var body: some View {
        ZStack {
            Palette.cream.ignoresSafeArea()

            VStack(spacing: 0) {
                navBar
                rowIndicator
                if voice, currentRow != nil {
                    voiceBanner
                }
                rowList
                footerControls
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .environment(\.openURL, OpenURLAction { url in
            guard url.scheme == "abbr" else { return .systemAction }
            let key = url.host ?? url.path.trimmingCharacters(in: .init(charactersIn: "/"))
            tappedAbbr = .init(abbr: key, definition: SampleData.abbreviations[key.lowercased()])
            return .handled
        })
        .sheet(item: $tappedAbbr) { item in
            AbbrSheet(item: item) { tappedAbbr = nil }
                .presentationDetents([.fraction(0.32)])
                .presentationDragIndicator(.visible)
                .presentationBackground(Palette.cream)
        }
    }

    // MARK: nav

    private var navBar: some View {
        HStack {
            CircleIconButton(system: "chevron.left") { dismiss() }
            Spacer()
            Text(SampleData.patternSection)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Palette.walnut)
            Spacer()
            HStack(spacing: 8) {
                Button {
                    voice.toggle()
                } label: {
                    Image(systemName: voice ? "speaker.wave.2.fill" : "speaker.wave.2")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(voice ? .white : Palette.walnut)
                        .frame(width: 38, height: 38)
                        .background(
                            Circle().fill(voice ? Palette.primary : Palette.paper.opacity(0.85))
                        )
                        .overlay(Circle().strokeBorder(Palette.line, lineWidth: 0.5))
                }
                .buttonStyle(PressScaleStyle())

                CircleIconButton(system: "ellipsis") {}
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 14)
    }

    // MARK: row indicator

    private var rowIndicator: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Current row").eyebrow(color: Palette.primaryDark)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(rowInRepeat)")
                        .font(AppFont.serif(30))
                        .foregroundStyle(Palette.walnut)
                        .monospacedDigit()
                    Text("of \(SampleData.rowsPerRepeat)").meta()
                }
                Text("Repeat \(repeatNumber) of \(totalRepeats) · Row \(current) of \(SampleData.patternTotalRows)")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.walnutMute)
                    .padding(.top, 2)
            }
            Spacer()
            if let r = currentRow {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Stitches").eyebrow()
                    Text("\(r.sts)")
                        .font(AppFont.mono(16, weight: .semibold))
                        .foregroundStyle(Palette.walnut)
                }
                .padding(.trailing, 16)
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Side").eyebrow()
                    Text(r.rs ? "RS" : "WS")
                        .font(AppFont.mono(14, weight: .semibold))
                        .foregroundStyle(r.rs ? Palette.primaryDark : Palette.accent)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
    }

    private var voiceBanner: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(.white)
                .frame(width: 8, height: 8)
                .overlay(
                    Circle()
                        .strokeBorder(Color.white.opacity(0.25), lineWidth: 6)
                )
            Text("Reading row \(current) — say \(Text("\"next\"").font(AppFont.mono(13, weight: .semibold))) to advance.")
                .foregroundStyle(.white)
                .font(.system(size: 13))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.primary))
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    // MARK: rows

    private var rowList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(rows) { r in
                        rowView(r)
                            .id(r.n)
                            .onTapGesture {
                                // Tapping a chart row sets us to that row inside the
                                // current repeat (not absolute row r.n).
                                let base = (max(repeatNumber, 1) - 1) * SampleData.rowsPerRepeat
                                withAnimation(.easeInOut(duration: 0.18)) {
                                    current = base + r.n
                                }
                            }
                    }
                    Color.clear.frame(height: 60)
                }
                .padding(.horizontal, 12)
            }
            .onChange(of: current) { _, _ in
                withAnimation(.easeInOut(duration: 0.3)) {
                    proxy.scrollTo(rowInRepeat, anchor: .center)
                }
            }
        }
    }

    @ViewBuilder
    private func rowView(_ r: PatternRow) -> some View {
        let state: RowState = (r.n < rowInRepeat ? .done :
                               r.n == rowInRepeat ? .current : .future)
        let textColor: Color = {
            switch state {
            case .current: return Palette.walnut
            case .done:    return Palette.walnutMute.opacity(0.7)
            case .future:  return Palette.walnutSoft
            }
        }()

        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .trailing, spacing: 1) {
                Text("\(r.n)")
                    .font(AppFont.mono(14, weight: .semibold))
                    .strikethrough(state == .done)
                    .foregroundStyle(state == .done ? Palette.walnutMute : Palette.primaryDark)
                Text(r.rs ? "RS" : "WS")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(textColor.opacity(0.7))
            }
            .frame(width: 36, alignment: .trailing)

            Text(tokenizedText(r.text, color: textColor))
                .frame(maxWidth: .infinity, alignment: .leading)
                .tint(textColor)

            Text("\(r.sts)st")
                .font(AppFont.mono(11))
                .foregroundStyle(textColor.opacity(0.55))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(state == .current
                      ? AnyShapeStyle(LinearGradient(
                          colors: [Palette.primarySoft, Palette.primary.opacity(0.45)],
                          startPoint: .top, endPoint: .bottom))
                      : AnyShapeStyle(Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(state == .current
                              ? Palette.primaryDark.opacity(0.30)
                              : Color.clear, lineWidth: 1)
        )
        .opacity(state == .done ? 0.55 : 1)
    }

    enum RowState { case done, current, future }

    // Make abbreviation tokens tappable. Splits on the same regex the JS does
    // (whitespace + common punctuation) so visible spacing/punctuation survives.
    // Each abbreviation becomes a `abbr://<key>` link — the screen's OpenURLAction
    // intercepts the scheme and shows the glossary sheet.
    private func tokenizedText(_ text: String, color: Color) -> AttributedString {
        let pattern = "(\\s+|,|\\.|;|\\*)"
        let regex = try! NSRegularExpression(pattern: pattern)
        let ns = text as NSString
        let full = NSRange(location: 0, length: ns.length)
        var pieces: [String] = []
        var cursor = 0
        regex.enumerateMatches(in: text, range: full) { m, _, _ in
            guard let m else { return }
            if m.range.location > cursor {
                pieces.append(ns.substring(with: NSRange(location: cursor,
                                                          length: m.range.location - cursor)))
            }
            pieces.append(ns.substring(with: m.range))
            cursor = m.range.location + m.range.length
        }
        if cursor < ns.length { pieces.append(ns.substring(from: cursor)) }

        var out = AttributedString()
        for piece in pieces {
            let key = piece
                .lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .joined()
            var part = AttributedString(piece)
            part.font = .system(size: 14, design: .monospaced)
            part.foregroundColor = color
            if !key.isEmpty, SampleData.abbreviations[key] != nil {
                part.font = .system(size: 14, weight: .semibold, design: .monospaced)
                part.underlineStyle = .single
                part.link = URL(string: "abbr://\(key)")
            }
            out.append(part)
        }
        return out
    }

    // MARK: footer

    private var footerControls: some View {
        HStack(spacing: 10) {
            Button {
                current = max(1, current - 1)
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Palette.walnut)
                    .frame(width: 56, height: 50)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Palette.creamSoft))
            }
            .buttonStyle(PressScaleStyle())

            Button {
                current = min(SampleData.patternTotalRows, current + 1)
            } label: {
                Text(sectionComplete ? "Section complete" : "Mark row \(rowInRepeat) done")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(RoundedRectangle(cornerRadius: 14)
                        .fill(sectionComplete ? Palette.walnutMute : Palette.primary))
            }
            .buttonStyle(PressScaleStyle())
            .disabled(sectionComplete)

            NavigationLink(value: Route.counter(projectId)) {
                Image(systemName: "number.square")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Palette.walnut)
                    .frame(width: 56, height: 50)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Palette.creamSoft))
            }
            .buttonStyle(PressScaleStyle())
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 14)
        .background(
            Palette.cream
                .opacity(0.92)
                .overlay(Rectangle().fill(Palette.line).frame(height: 0.5), alignment: .top)
        )
    }
}

private struct AbbrSheet: View {
    let item: PatternViewerScreen.TappedAbbr
    var onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(item.abbr)
                .font(AppFont.mono(26, weight: .semibold))
                .foregroundStyle(Palette.primaryDark)
            Text(item.definition ?? "No definition found yet — tap to add one.")
                .font(.system(size: 16))
                .foregroundStyle(Palette.walnut)
            Spacer(minLength: 0)
            SoftButton(title: "Got it", fill: true, action: onDismiss)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    @Previewable @State var path = NavigationPath()
    NavigationStack(path: $path) {
        PatternViewerScreen(projectId: "p1")
            .navigationDestinationForRoutes()
    }
    .environment(PatternStore.shared)
    .tint(Palette.primary)
}
