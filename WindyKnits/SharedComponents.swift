import SwiftUI

struct SoftCard<Content: View>: View {
    var padding: CGFloat = 18
    var radius: CGFloat = 22
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Palette.paper)
                    .shadow(color: Palette.walnut.opacity(0.12),
                            radius: 11, x: 0, y: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Palette.walnut.opacity(0.06), lineWidth: 0.5)
            )
    }
}

struct ProgressBar: View {
    var value: Double // 0…1
    var height: CGFloat = 6
    var color: Color = Palette.primary

    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.creamSoft)
                Capsule()
                    .fill(color)
                    .frame(width: max(0, min(1, value)) * g.size.width)
                    .animation(.easeOut(duration: 0.35), value: value)
            }
        }
        .frame(height: height)
    }
}

struct Segmented<Value: Hashable>: View {
    @Binding var selection: Value
    let options: [(Value, String)]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.0) { (val, label) in
                let active = val == selection
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                        selection = val
                    }
                } label: {
                    Text(label)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(active ? Palette.walnut : Palette.walnutMute)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 14)
                        .background(
                            ZStack {
                                if active {
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
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Palette.creamSoft)
        )
    }
}

struct Chip: View {
    let text: String
    var monospaced: Bool = false
    var body: some View {
        Text(text)
            .font(monospaced
                  ? AppFont.mono(12, weight: .semibold)
                  : .system(size: 12, weight: .semibold))
            .foregroundStyle(Palette.walnutSoft)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(Palette.creamSoft))
    }
}

struct PrimaryButton: View {
    let title: String
    var icon: String? = nil
    var fill: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon { Image(systemName: icon) }
                Text(title)
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: fill ? .infinity : nil)
            .padding(.vertical, 14)
            .padding(.horizontal, 20)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Palette.primary)
            )
        }
        .buttonStyle(PressScaleStyle())
    }
}

struct SoftButton: View {
    var icon: String? = nil
    var title: String? = nil
    var fill: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon { Image(systemName: icon) }
                if let title { Text(title) }
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Palette.walnut)
            .frame(maxWidth: fill ? .infinity : nil)
            .padding(.vertical, 14)
            .padding(.horizontal, 18)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Palette.creamSoft)
            )
        }
        .buttonStyle(PressScaleStyle())
    }
}

struct PressScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

// Diagonal-hatched placeholder used wherever the prototype has photo art.
struct PhotoPlaceholder: View {
    var label: String = "photo"
    var radius: CGFloat = 16
    var tint: Color? = nil

    var body: some View {
        ZStack {
            Palette.creamSoft
            HatchPattern().stroke(Palette.walnut.opacity(0.10), lineWidth: 1)
            if let tint {
                LinearGradient(colors: [tint.opacity(0.2), tint.opacity(0.55)],
                               startPoint: .top, endPoint: .bottom)
            }
            Text(label.uppercased())
                .font(AppFont.mono(10, weight: .medium))
                .tracking(1.6)
                .foregroundStyle(Palette.walnutMute)
        }
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

private struct HatchPattern: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let step: CGFloat = 9
        let diag = rect.width + rect.height
        var x = -rect.height
        while x < diag {
            p.move(to: CGPoint(x: x, y: 0))
            p.addLine(to: CGPoint(x: x + rect.height, y: rect.height))
            x += step
        }
        return p
    }
}

struct CircleIconButton: View {
    let system: String
    var size: CGFloat = 38
    var background: Color = Palette.paper.opacity(0.85)
    var tint: Color = Palette.walnut
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: size, height: size)
                .background(Circle().fill(background))
                .overlay(Circle().strokeBorder(Palette.line, lineWidth: 0.5))
        }
        .buttonStyle(PressScaleStyle())
    }
}

// A wool-ball-ish swatch — used in the home list to indicate a project's yarn color.
struct YarnSwatch: View {
    let color: Color
    var size: CGFloat = 54
    var corner: CGFloat = 12

    var body: some View {
        RoundedRectangle(cornerRadius: corner, style: .continuous)
            .fill(color)
            .frame(width: size, height: size)
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.06), lineWidth: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.clear, Color.black.opacity(0.10)],
                            startPoint: .top, endPoint: .bottom)
                    )
            )
    }
}

// Custom knitting-needle glyph: a long line with a ball on one end.
struct NeedleIcon: View {
    var size: CGFloat = 20
    var color: Color = Palette.walnut
    var body: some View {
        Canvas { ctx, sz in
            let lineWidth: CGFloat = max(1.6, sz.width * 0.09)
            var line = Path()
            line.move(to: CGPoint(x: sz.width * 0.10, y: sz.height * 0.88))
            line.addLine(to: CGPoint(x: sz.width * 0.80, y: sz.height * 0.18))
            ctx.stroke(line, with: .color(color),
                       style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            let r = sz.width * 0.11
            let ball = Path(ellipseIn: CGRect(x: sz.width * 0.80 - r,
                                              y: sz.height * 0.18 - r,
                                              width: r * 2, height: r * 2))
            ctx.stroke(ball, with: .color(color), lineWidth: lineWidth)
        }
        .frame(width: size, height: size)
    }
}

// Bouncing dots for parsing animation.
struct BouncingDots: View {
    @State private var phase: Double = 0
    var color: Color = Palette.primary

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                    .offset(y: bounce(for: i))
                    .opacity(opacity(for: i))
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                phase = 1
            }
        }
    }

    private func bounce(for i: Int) -> CGFloat {
        let offset = Double(i) * 0.15
        let p = (phase + offset).truncatingRemainder(dividingBy: 1)
        if p < 0.4 { return -CGFloat(sin(p / 0.4 * .pi)) * 6 }
        return 0
    }
    private func opacity(for i: Int) -> Double {
        let offset = Double(i) * 0.15
        let p = (phase + offset).truncatingRemainder(dividingBy: 1)
        return p < 0.4 ? 0.4 + sin(p / 0.4 * .pi) * 0.6 : 0.4
    }
}
