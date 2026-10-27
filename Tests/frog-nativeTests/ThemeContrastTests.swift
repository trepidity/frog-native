import AppKit
import SwiftUI
import Testing
@testable import frog_native

struct ThemeContrastTests {
    // Handoff sections 1, 4, 5, 7: every readable ink clears 4.5:1 on its surface.
    // Catches replacing accessible accents with canonical Solarized colors, or
    // using ordinary row ink on the lighter/darker hover surface.
    @Test(arguments: FileManagerTheme.allCases)
    func readableInkMeetsContrastFloor(theme: FileManagerTheme) throws {
        let palette = theme.palette
        let regularSurfaces = [palette.bg, palette.bg2, palette.panel, palette.selection]
        for surface in regularSurfaces {
            for ink in inks(palette.ink) {
                #expect(try contrast(ink, surface) >= 4.5)
            }
        }
        for ink in inks(palette.raisedInk) {
            #expect(try contrast(ink, palette.panel2) >= 4.5)
        }
    }

    private func inks(_ ink: ThemeInk) -> [Color] {
        [ink.primary, ink.secondary, ink.muted, ink.blue, ink.good,
         ink.bad, ink.warn, ink.cyan, ink.violet]
    }

    private func contrast(_ first: Color, _ second: Color) throws -> Double {
        let a = try luminance(first)
        let b = try luminance(second)
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }

    private func luminance(_ color: Color) throws -> Double {
        let rgb = try #require(NSColor(color).usingColorSpace(.sRGB))
        func linear(_ channel: Double) -> Double {
            channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(rgb.redComponent)
            + 0.7152 * linear(rgb.greenComponent)
            + 0.0722 * linear(rgb.blueComponent)
    }
}
