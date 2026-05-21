import SwiftUI

// `Palette` and `Color(hex:)` live in Shared/Palette.swift so the Live
// Activity can render in the same brand colors. The rest of the design
// tokens below stay app-only (the widget doesn't need them).

enum AppFont {
    static func serif(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
    static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
    static func mono(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

extension View {
    func eyebrow(color: Color = Palette.walnutMute) -> some View {
        self.font(.system(size: 11, weight: .semibold))
            .tracking(1.4)
            .textCase(.uppercase)
            .foregroundStyle(color)
    }
    func meta(size: CGFloat = 13) -> some View {
        self.font(.system(size: size, weight: .medium))
            .foregroundStyle(Palette.walnutMute)
    }
}
