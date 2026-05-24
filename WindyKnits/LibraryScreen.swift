import SwiftUI

struct LibraryScreen: View {
    @Environment(PatternStore.self) private var store
    @State private var filter: ProjectStatus = .active

    /// Project whose status sheet is open (from kebab or swipe-left → Move).
    @State private var statusSheetFor: Project? = nil
    /// Project being deleted (from sheet "Delete project…" or swipe-left → Delete).
    @State private var deleteFor: Project? = nil
    /// Which row is currently revealing its swipe actions. Mutually exclusive
    /// across rows so a new swipe collapses the previous one.
    @State private var swipedRow: String? = nil

    var body: some View {
        ZStack {
            Palette.cream.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    filterRow
                    list
                }
                .padding(.bottom, 32)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $statusSheetFor) { project in
            StatusSheet(
                projectTitle: project.title,
                status: project.status,
                onMove: { next in
                    statusSheetFor = nil
                    guard next != project.status else { return }
                    store.setStatus(project.id, to: next)
                    withAnimation { filter = next }
                },
                onDelete: {
                    statusSheetFor = nil
                    // Defer the next sheet by one tick so iOS finishes
                    // dismissing the move sheet before presenting delete.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        deleteFor = project
                    }
                }
            )
        }
        .sheet(item: $deleteFor) { project in
            DeleteConfirmSheet(
                projectTitle: project.title,
                onCancel: { deleteFor = nil },
                onConfirm: {
                    store.delete(project.id)
                    deleteFor = nil
                }
            )
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            Text("Projects")
                .font(AppFont.serif(34))
                .foregroundStyle(Palette.walnut)
            Spacer()
            NavigationLink(value: Route.importPDF) {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Palette.primary))
            }
            .buttonStyle(PressScaleStyle())
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 8)
    }

    private var filterRow: some View {
        let counts = store.counts()
        return HStack(spacing: 0) {
            ForEach(ProjectStatus.allCases, id: \.self) { s in
                FilterTab(
                    label: s.label,
                    count: counts[s] ?? 0,
                    selected: filter == s
                ) {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                        filter = s
                        swipedRow = nil
                    }
                }
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Palette.creamSoft)
        )
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var list: some View {
        let items = store.projects(in: filter)
        if items.isEmpty {
            LibraryEmptyState(filter: filter)
                .padding(.top, 8)
        } else {
            VStack(spacing: 12) {
                ForEach(items) { p in
                    SwipeRow(
                        revealed: Binding(
                            get: { swipedRow == p.id },
                            set: { open in swipedRow = open ? p.id : nil }
                        ),
                        onMove:   { openStatusSheet(for: p) },
                        onDelete: { deleteFor = p }
                    ) {
                        LibraryRow(
                            project: p,
                            onMore:    { openStatusSheet(for: p) },
                            onCastOn:  { castOn(p) }
                        )
                    }
                    .onChange(of: filter) { _, _ in
                        // Closing all swipes on tab change happens via the
                        // shared swipedRow state — but if a project moves
                        // tabs while its row is open, force-collapse so the
                        // new row doesn't appear mid-swipe.
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .simultaneousGesture(
                // Tapping anywhere in the list (outside the swipe-revealed
                // actions) collapses the open row.
                TapGesture().onEnded {
                    if swipedRow != nil {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                            swipedRow = nil
                        }
                    }
                }
            )
        }
    }

    private func openStatusSheet(for project: Project) {
        swipedRow = nil
        statusSheetFor = project
    }

    private func castOn(_ project: Project) {
        store.setStatus(project.id, to: .active)
        withAnimation { filter = .active }
    }
}

// MARK: - Filter tab

private struct FilterTab: View {
    let label: String
    let count: Int
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(selected ? Palette.walnut : Palette.walnutMute)
                Text("\(count)")
                    .font(AppFont.mono(10, weight: .semibold))
                    .foregroundStyle(selected ? Palette.walnutSoft : Palette.walnutMute)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(
                        Capsule().fill(
                            selected ? Palette.creamSoft : Palette.walnut.opacity(0.10)
                        )
                    )
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                Group {
                    if selected {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(Palette.paper)
                            .shadow(color: Palette.walnut.opacity(0.10),
                                    radius: 2, x: 0, y: 1)
                    }
                }
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Swipe row

/// Wraps a row in a swipe-to-reveal container that exposes Move + Delete
/// buttons beneath. Matches the prototype's `SwipeRevealed` — 76pt-wide
/// buttons for ~152pt total reveal.
private struct SwipeRow<Content: View>: View {
    @Binding var revealed: Bool
    var onMove:   () -> Void
    var onDelete: () -> Void
    @ViewBuilder var content: () -> Content

    @State private var dragOffset: CGFloat = 0

    private static var actionWidth: CGFloat { 76 }
    private static var revealWidth: CGFloat { actionWidth * 2 }

    var body: some View {
        content()
            .background(alignment: .trailing) {
                // Action layer sits behind the row, sized to match content
                // height via the row's intrinsic geometry. `clipped()` keeps
                // the buttons from spilling out before the row peels back.
                HStack(spacing: 0) {
                    actionButton(
                        label: "Move",
                        icon: "arrow.uturn.up",
                        background: Palette.walnutSoft,
                        action: onMove
                    )
                    actionButton(
                        label: "Delete",
                        icon: "trash",
                        background: StatusSheet.destructive,
                        action: onDelete
                    )
                }
                .frame(width: Self.revealWidth)
                .opacity(revealAmount)
            }
            .offset(x: currentOffset)
            .animation(.spring(response: 0.28, dampingFraction: 0.85),
                       value: revealed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 12)
                    .onChanged { value in
                        // Horizontal drags only. The check keeps vertical
                        // scrolls from accidentally peeling the row.
                        guard abs(value.translation.width) > abs(value.translation.height) else { return }
                        let base: CGFloat = revealed ? -Self.revealWidth : 0
                        let proposed = base + value.translation.width
                        // Clamp: never push the row to the right, and
                        // resist past the full reveal.
                        if proposed > 0 {
                            dragOffset = -base
                        } else if proposed < -Self.revealWidth {
                            let over = proposed + Self.revealWidth
                            dragOffset = (-Self.revealWidth - base) + over * 0.35
                        } else {
                            dragOffset = proposed - base
                        }
                    }
                    .onEnded { value in
                        let velocity = value.predictedEndTranslation.width - value.translation.width
                        let final = (revealed ? -Self.revealWidth : 0) + value.translation.width + velocity * 0.2
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                            dragOffset = 0
                            revealed = final < -Self.revealWidth / 2
                        }
                    }
            )
    }

    private var currentOffset: CGFloat {
        (revealed ? -Self.revealWidth : 0) + dragOffset
    }

    private var revealAmount: Double {
        min(1.0, Double(-currentOffset) / 20.0)
    }

    private func actionButton(label: String, icon: String,
                              background: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                Text(label)
                    .font(.system(size: 11, weight: .bold))
            }
            .foregroundStyle(.white)
            .frame(width: Self.actionWidth)
            .frame(maxHeight: .infinity)
            .background(background)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Row

/// Status-aware library row. The card chrome (photo, title, designer,
/// kebab) is shared; the bottom block varies per status.
private struct LibraryRow: View {
    let project: Project
    let onMore: () -> Void
    let onCastOn: () -> Void

    var body: some View {
        NavigationLink(value: Route.project(project.id)) {
            SoftCard(padding: 14) {
                HStack(alignment: .top, spacing: 14) {
                    photo
                    VStack(alignment: .leading, spacing: 0) {
                        header
                        Spacer(minLength: 8)
                        Group {
                            switch project.status {
                            case .active:   activeFooter
                            case .queue:    queueFooter
                            case .finished: finishedFooter
                            }
                        }
                    }
                    .frame(maxHeight: .infinity)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var photo: some View {
        PhotoPlaceholder(label: "photo", radius: 12, tint: project.swatch)
            .frame(width: 72, height: 88)
            .saturation(project.status == .finished ? 0.85 : 1)
            .overlay(alignment: .topTrailing) {
                if project.status == .finished {
                    ZStack {
                        Circle().fill(Palette.accent)
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 22, height: 22)
                    .padding(6)
                }
            }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(project.title)
                    .font(AppFont.serif(17))
                    .foregroundStyle(Palette.walnut)
                    .lineLimit(2)
                Text(project.designer).meta(size: 12)
            }
            Spacer()
            Button(action: onMore) {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Palette.walnutMute)
                    .frame(width: 30, height: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressScaleStyle())
            .offset(x: 6, y: -4)
        }
    }

    private var activeFooter: some View {
        let pct = Int((project.progress * 100).rounded())
        return VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(project.rowsDone)/\(project.rowsTotal) rows · \(pct)%")
                    .font(AppFont.mono(11))
                    .foregroundStyle(Palette.walnutMute)
                Spacer()
                Text(project.lastWorked).meta(size: 11)
            }
            ProgressBar(value: project.progress)
        }
    }

    @ViewBuilder
    private var queueFooter: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(project.swatch)
                        .frame(width: 8, height: 8)
                        .overlay(Circle().strokeBorder(.black.opacity(0.15), lineWidth: 0.5))
                    Text(project.yarn.isEmpty ? "Yarn TBD" : project.yarn)
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.walnutSoft)
                        .lineLimit(1)
                }
                if let est = project.estWeeks {
                    Text("·")
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.walnutMute)
                    Text("~\(est)w").meta(size: 11)
                }
                Spacer(minLength: 0)
                if project.yarnReady == true {
                    Text("YARN READY")
                        .font(.system(size: 9.5, weight: .bold))
                        .tracking(0.5)
                        .foregroundStyle(Palette.accent)
                }
            }
            Button(action: onCastOn) {
                Text("Cast on")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Palette.primary)
                    )
            }
            .buttonStyle(PressScaleStyle())
        }
    }

    private var finishedFooter: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Finished")
                    .font(.system(size: 9.5, weight: .bold))
                    .tracking(0.5)
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.accent)
                Text(project.finishedOn ?? "—")
                    .font(AppFont.mono(12, weight: .semibold))
                    .foregroundStyle(Palette.walnut)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text("Took").eyebrow()
                Text("\(project.daysToFinish ?? 0) days")
                    .font(AppFont.mono(12, weight: .semibold))
                    .foregroundStyle(Palette.walnutSoft)
            }
        }
    }
}

// MARK: - Empty state

private struct LibraryEmptyState: View {
    let filter: ProjectStatus

    private var copy: (head: String, sub: String) {
        switch filter {
        case .active:
            return ("No projects on the needles.",
                    "Cast on something from the queue, or add a new pattern.")
        case .queue:
            return ("The queue is empty.",
                    "Save patterns here when you find one to knit next.")
        case .finished:
            return ("Nothing finished yet.",
                    "When you complete a project it lands here.")
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            Text(copy.head)
                .font(AppFont.serif(20))
                .foregroundStyle(Palette.walnut)
                .multilineTextAlignment(.center)
            Text(copy.sub)
                .font(.system(size: 13))
                .foregroundStyle(Palette.walnutSoft)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
                .lineSpacing(2)
            NavigationLink(value: Route.importPDF) {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                    Text("Add a pattern")
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.walnut)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Capsule().fill(Palette.creamSoft))
            }
            .buttonStyle(PressScaleStyle())
            .padding(.top, 8)
        }
        .padding(.horizontal, 24)
        .padding(.top, 40)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    NavigationStack { LibraryScreen() }
        .environment(PatternStore.shared)
        .tint(Palette.primary)
}
