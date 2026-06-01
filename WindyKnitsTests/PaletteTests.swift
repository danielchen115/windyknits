import Testing
import Foundation
import SwiftUI
import UIKit
@testable import WindyKnits

@MainActor
@Suite("Color(hex:)")
struct ColorHexInitTests {

    private func components(_ color: Color) -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b, a)
    }

    @Test func decodesFullRange() {
        let c = Color(hex: 0xff8800)
        let comps = components(c)
        #expect(abs(comps.r - 1.0) < 0.01)
        #expect(abs(comps.g - (0x88 / 255.0)) < 0.01)
        #expect(abs(comps.b - 0.0) < 0.01)
        #expect(abs(comps.a - 1.0) < 0.01)
    }

    @Test func decodesPureBlack() {
        let c = Color(hex: 0x000000)
        let comps = components(c)
        #expect(comps.r < 0.01 && comps.g < 0.01 && comps.b < 0.01)
    }

    @Test func decodesPureWhite() {
        let c = Color(hex: 0xffffff)
        let comps = components(c)
        #expect(comps.r > 0.99 && comps.g > 0.99 && comps.b > 0.99)
    }

    @Test func honoursAlphaArgument() {
        let c = Color(hex: 0xff0000, alpha: 0.5)
        let comps = components(c)
        #expect(abs(comps.a - 0.5) < 0.01)
    }
}

@MainActor
@Suite("Palette")
struct PaletteTests {

    @Test func primaryColorMatchesAdvertisedHex() {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(Palette.primary).getRed(&r, green: &g, blue: &b, alpha: &a)
        #expect(abs(r - (0xd4 / 255.0)) < 0.01)
        #expect(abs(g - (0x9a / 255.0)) < 0.01)
        #expect(abs(b - (0xa3 / 255.0)) < 0.01)
    }

    @Test func statusColorsAreFromPalette() {
        // Just confirm the mapping doesn't crash and produces distinct colors per status.
        let active   = ProjectStatus.active.color
        let queue    = ProjectStatus.queue.color
        let finished = ProjectStatus.finished.color
        // Make UIColor descriptions to compare uniqueness without depending on Color equality.
        let descs = [active, queue, finished].map { UIColor($0).description }
        #expect(Set(descs).count == 3, "Each status should map to a distinct color")
    }
}
