import SwiftUI

// Blossom palette — dusty rose primary, lilac accent, blush cream background.
enum Palette {
    static let cream       = Color(hex: 0xfbe7e6)
    static let creamWarm   = Color(hex: 0xfdf0ee)
    static let creamSoft   = Color(hex: 0xf3d3d2)
    static let primary     = Color(hex: 0xd49aa3)
    static let primaryDark = Color(hex: 0xb6707c)
    static let primarySoft = Color(hex: 0xe8c2c8)
    static let walnut      = Color(hex: 0x4a2e36)
    static let walnutSoft  = Color(hex: 0x6b4651)
    static let walnutMute  = Color(hex: 0xa17e87)
    static let accent      = Color(hex: 0xc8a7c4)
    static let paper       = Color(hex: 0xfef5f4)
    static let line        = Color(hex: 0x4a2e36).opacity(0.10)
    static let lineStrong  = Color(hex: 0x4a2e36).opacity(0.20)
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        let r = Double((hex >> 16) & 0xff) / 255
        let g = Double((hex >>  8) & 0xff) / 255
        let b = Double( hex        & 0xff) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}

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
