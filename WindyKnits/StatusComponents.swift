import SwiftUI

// MARK: - StatusBadge

/// Small pill that shows where a project sits in the workflow. Appears
/// under the project-detail back button (tappable, with chevron) and inline
/// on saved-confirm copy (non-interactive). The colored dot matches
/// `ProjectStatus.color`; the `active` variant adds a soft halo to flag the
/// "currently on the needles" state.
struct StatusBadge: View {
    var status: ProjectStatus
    /// When true, renders the chip background + chevron and routes taps to
    /// `onTap`. When false, the label sits inline with no chrome.
    var clickable: Bool = false
    var onTap: (() -> Void)? = nil

    var body: some View {
        let label = HStack(spacing: 6) {
            ZStack {
                if status == .active {
                    Circle().fill(status.color.opacity(0.22))
                        .frame(width: 13, height: 13)
                }
                Circle().fill(status.color)
                    .frame(width: 7, height: 7)
            }
            Text(status.label)
                .font(.system(size: 11, weight: .bold))
                .tracking(1.1)
                .textCase(.uppercase)
                .foregroundStyle(status.color)
            if clickable {
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(status.color.opacity(0.65))
            }
        }
        .padding(.horizontal, clickable ? 12 : 0)
        .padding(.vertical,   clickable ? 5  : 0)
        .background(
            Group {
                if clickable {
                    Capsule().fill(Palette.paper.opacity(0.9))
                        .overlay(Capsule().strokeBorder(Palette.line, lineWidth: 0.5))
                }
            }
        )

        if clickable {
            Button { onTap?() } label: { label }
                .buttonStyle(PressScaleStyle())
        } else {
            label
        }
    }
}

// MARK: - StatusSheet

/// Bottom sheet that opens from three places: the project-detail "..." button,
/// a library row's kebab, or a swipe-left → Move. Same UI everywhere: a radio
/// list of statuses, a divider, then a destructive Delete button.
struct StatusSheet: View {
    let projectTitle: String
    let status: ProjectStatus
    var onMove: (ProjectStatus) -> Void
    var onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Project").eyebrow()
                Text(projectTitle)
                    .font(AppFont.serif(18))
                    .foregroundStyle(Palette.walnut)
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 14)

            Text("Move to").eyebrow()
                .padding(.leading, 4)
                .padding(.bottom, 8)

            VStack(spacing: 6) {
                ForEach(ProjectStatus.allCases, id: \.self) { s in
                    StatusRow(status: s, selected: s == status) {
                        onMove(s)
                    }
                }
            }

            Rectangle().fill(Palette.line)
                .frame(height: 1)
                .padding(.vertical, 10)

            Button(action: onDelete) {
                HStack(spacing: 12) {
                    Image(systemName: "trash")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Delete project…")
                        .font(.system(size: 14, weight: .semibold))
                    Spacer()
                }
                .foregroundStyle(Self.destructive)
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
                .contentShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(PressScaleStyle())
        }
        .padding(.horizontal, 16)
        .padding(.top, 18)
        .padding(.bottom, 22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .presentationDetents([.height(360)])
        .presentationDragIndicator(.visible)
        .presentationBackground(Palette.cream)
    }

    static let destructive = Color(hex: 0xa14e4e)
}

private struct StatusRow: View {
    let status: ProjectStatus
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    if status == .active {
                        Circle().fill(status.color.opacity(0.22))
                            .frame(width: 16, height: 16)
                    }
                    Circle().fill(status.color)
                        .frame(width: 10, height: 10)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(status.label)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Palette.walnut)
                    Text(status.sub)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Palette.walnutMute)
                }
                Spacer()
                if selected {
                    ZStack {
                        Circle().fill(status.color)
                            .frame(width: 22, height: 22)
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(selected ? Palette.paper : .clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(selected ? Palette.line : .clear, lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(PressScaleStyle())
    }
}

// MARK: - DeleteConfirmSheet

/// Two-step destructive confirmation. The first sheet is the Status sheet's
/// Delete button; this is the second. Copy clarifies what's removed (rows,
/// notes, photos for this project) vs what stays (the pattern itself).
struct DeleteConfirmSheet: View {
    let projectTitle: String
    var onCancel: () -> Void
    var onConfirm: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle().fill(StatusSheet.destructive.opacity(0.10))
                Image(systemName: "trash")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(StatusSheet.destructive)
            }
            .frame(width: 52, height: 52)
            .padding(.top, 4)

            VStack(spacing: 8) {
                Text("Delete \(projectTitle)?")
                    .font(AppFont.serif(22))
                    .foregroundStyle(Palette.walnut)
                    .multilineTextAlignment(.center)
                Text("Your row counts, notes, and photos for this project will be removed. The pattern itself stays in your pattern library.")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.walnutSoft)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
            .padding(.top, 14)
            .padding(.horizontal, 14)

            HStack(spacing: 10) {
                Button(action: onCancel) {
                    Text("Cancel")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Palette.walnut)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Palette.creamSoft)
                        )
                }
                .buttonStyle(PressScaleStyle())

                Button(action: onConfirm) {
                    Text("Delete")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(StatusSheet.destructive)
                        )
                }
                .buttonStyle(PressScaleStyle())
            }
            .padding(.top, 18)
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 28)
        .frame(maxWidth: .infinity)
        .presentationDetents([.height(320)])
        .presentationDragIndicator(.visible)
        .presentationBackground(Palette.cream)
    }
}

// MARK: - DestinationChooser

/// Two-up picker shown at the bottom of the import-review step. Picks where
/// the newly-saved project lives. `finished` is intentionally absent — it's
/// a terminal state, never a starting one.
struct DestinationChooser: View {
    @Binding var value: ProjectStatus  // .active or .queue only

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Where should this live?").eyebrow()
                .padding(.leading, 2)
            HStack(spacing: 10) {
                DestinationCard(
                    choice: .active,
                    selected: value == .active,
                    label: "Casting on now",
                    sub: "Add to In progress",
                    accent: Palette.primary,
                    icon: NeedleGlyph()
                ) { value = .active }

                DestinationCard(
                    choice: .queue,
                    selected: value == .queue,
                    label: "Save for later",
                    sub: "Add to Queue",
                    accent: Palette.walnutSoft,
                    icon: ListGlyph()
                ) { value = .queue }
            }
        }
    }
}

/// Diagonal-needle SVG path from the prototype, redrawn in SwiftUI.
private struct NeedleGlyph: View {
    var body: some View {
        Canvas { ctx, sz in
            let w = sz.width
            let h = sz.height
            let stroke: CGFloat = max(1.6, w * 0.085)
            var line = Path()
            line.move(to: CGPoint(x: w * 0.12, y: h * 0.88))
            line.addLine(to: CGPoint(x: w * 0.74, y: h * 0.30))
            ctx.stroke(line, with: .color(.white),
                       style: StrokeStyle(lineWidth: stroke, lineCap: .round))
            let r = w * 0.13
            let ball = Path(ellipseIn: CGRect(x: w * 0.74 - r, y: h * 0.30 - r,
                                              width: r * 2, height: r * 2))
            ctx.stroke(ball, with: .color(.white), lineWidth: stroke)
        }
        .frame(width: 22, height: 22)
    }
}

/// Four-line "list" glyph matching the Save-for-later button in the design.
private struct ListGlyph: View {
    var body: some View {
        Canvas { ctx, sz in
            let w = sz.width
            let h = sz.height
            let stroke: CGFloat = max(1.4, w * 0.075)
            let xs = [0.25, 0.40, 0.55, 0.70]
            let widths: [Double] = [1.0, 1.0, 0.78, 0.65]
            for (i, y) in xs.enumerated() {
                var p = Path()
                p.move(to: CGPoint(x: w * 0.25, y: h * y))
                p.addLine(to: CGPoint(x: w * (0.25 + 0.50 * widths[i]), y: h * y))
                ctx.stroke(p, with: .color(.white),
                           style: StrokeStyle(lineWidth: stroke, lineCap: .round))
            }
        }
        .frame(width: 22, height: 22)
    }
}

private struct DestinationCard<Icon: View>: View {
    let choice: ProjectStatus
    let selected: Bool
    let label: String
    let sub: String
    let accent: Color
    let icon: Icon
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(selected ? accent : Palette.creamSoft)
                    icon
                        .foregroundStyle(selected ? .white : Palette.walnutSoft)
                }
                .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Palette.walnut)
                    Text(sub).meta(size: 11)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(selected
                          ? accent.opacity(0.10)
                          : Palette.creamWarm)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(selected ? accent : .clear, lineWidth: 1.5)
                    )
            )
            .overlay(alignment: .topTrailing) {
                if selected {
                    ZStack {
                        Circle().fill(accent)
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 18, height: 18)
                    .padding(10)
                }
            }
        }
        .buttonStyle(PressScaleStyle())
    }
}
