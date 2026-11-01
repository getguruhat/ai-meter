import SwiftUI
import AppKit

// The menu's look, shared with ServerHat: a grey rounded page, white cards on it,
// capsule pills and round icon buttons.

/// The menu's own palette, light or dark with the system appearance: a grey page,
/// cards that stand out from it, vivid accents.
enum Theme {
    static let page = dynamic(rgb(0.953, 0.957, 0.969), rgb(0.078, 0.078, 0.086))
    static let card = dynamic(.white, rgb(0.118, 0.122, 0.133))
    static let accent = dynamic(rgb(0.263, 0.384, 1.0), rgb(0.322, 0.435, 1.0))
    static let green = dynamic(rgb(0.086, 0.678, 0.369), rgb(0.263, 0.812, 0.494))
    static let red = dynamic(rgb(0.882, 0.227, 0.227), rgb(0.937, 0.333, 0.333))
    static let orange = dynamic(rgb(0.961, 0.502, 0.098), rgb(1.0, 0.616, 0.263))
    static let text = dynamic(rgb(0.102, 0.110, 0.137), rgb(0.961, 0.965, 0.973))
    static let secondary = dynamic(rgb(0.420, 0.443, 0.494), rgb(0.616, 0.635, 0.678))
    static let stroke = dynamic(NSColor.black.withAlphaComponent(0.08), NSColor.white.withAlphaComponent(0.09))
    static let control = dynamic(rgb(0.937, 0.941, 0.953), rgb(0.180, 0.184, 0.200))

    /// Bar color for what's left: green, orange below 50%, red below 20%, like the Windows panel.
    static func level(_ remaining: Int) -> Color {
        remaining >= 50 ? green : remaining >= 20 ? orange : red
    }

    private static func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> NSColor {
        NSColor(srgbRed: r, green: g, blue: b, alpha: 1)
    }

    private static func dynamic(_ light: NSColor, _ dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
        })
    }
}

struct CircleButtonStyle: ButtonStyle {
    var size: CGFloat = 32
    var fill: Color = Theme.card
    var foreground: Color = Theme.text

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(foreground)
            .frame(width: size, height: size)
            .background(Circle().fill(fill))
            .overlay(Circle().strokeBorder(Theme.stroke))
            .opacity(configuration.isPressed ? 0.7 : 1)
            .contentShape(Circle())
    }
}

extension View {
    func card(padding: CGFloat = 14) -> some View {
        self.padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.card))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.stroke))
    }
}
