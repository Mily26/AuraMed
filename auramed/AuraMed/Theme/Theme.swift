import SwiftUI
import CoreText

// MARK: - Colors (Serene Apothecary Minimal)

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

enum Aura {
    static let surface = Color(hex: 0xFFF8F4)
    static let surfaceLowest = Color.white
    static let surfaceLow = Color(hex: 0xFAF2ED)
    static let surfaceContainer = Color(hex: 0xF4ECE7)
    static let surfaceHigh = Color(hex: 0xEEE7E2)
    static let surfaceHighest = Color(hex: 0xE8E1DC)

    static let onSurface = Color(hex: 0x1E1B18)
    static let onSurfaceVariant = Color(hex: 0x434844)
    static let outline = Color(hex: 0x737873)
    static let outlineVariant = Color(hex: 0xC3C8C2)

    static let primary = Color(hex: 0x4D6054)
    static let primaryContainer = Color(hex: 0x66796C)
    static let primaryFixed = Color(hex: 0xD2E8D8)
    static let primaryFixedDim = Color(hex: 0xB7CCBC)

    static let secondary = Color(hex: 0x885038)
    static let secondaryContainer = Color(hex: 0xFFB597)
    static let secondaryFixed = Color(hex: 0xFFDBCD)
    static let onSecondaryContainer = Color(hex: 0x7A442D)

    static let tertiary = Color(hex: 0x5E5C55)
    static let error = Color(hex: 0xBA1A1A)

    static let hairline = Color(hex: 0x1E1B18, opacity: 0.05)
    static let softShadow = Color(hex: 0x5C5650, opacity: 0.08)

    // Spacing
    static let margin: CGFloat = 20
    static let spaceXS: CGFloat = 4
    static let spaceSM: CGFloat = 8
    static let spaceMD: CGFloat = 16
    static let spaceLG: CGFloat = 24
    static let spaceXL: CGFloat = 40

    // Radii
    static let radiusSM: CGFloat = 8
    static let radius: CGFloat = 16
    static let radiusMD: CGFloat = 24
    static let radiusLG: CGFloat = 32
}

// MARK: - Typography

/// EB Garamond (headlines) + Plus Jakarta Sans (interface). If the font files are
/// bundled in `Fonts/` they are registered at launch; otherwise system serif / sans
/// fallbacks keep the same hierarchy.
enum AuraFonts {
    static func registerBundledFonts() {
        let exts = ["ttf", "otf"]
        for ext in exts {
            for url in Bundle.main.urls(forResourcesWithExtension: ext, subdirectory: nil) ?? [] {
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            }
        }
        hasGaramond = UIFont(name: "EBGaramond-Regular", size: 12) != nil
            || UIFont.familyNames.contains("EB Garamond")
        hasJakarta = UIFont(name: "PlusJakartaSans-Regular", size: 12) != nil
            || UIFont.familyNames.contains("Plus Jakarta Sans")
    }

    static private(set) var hasGaramond = false
    static private(set) var hasJakarta = false
}

extension Font {
    /// Editorial serif — EB Garamond.
    static func serif(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        if AuraFonts.hasGaramond {
            return .custom("EB Garamond", size: size).weight(weight)
        }
        return .system(size: size, weight: weight, design: .serif)
    }

    /// Interface sans — Plus Jakarta Sans.
    static func sans(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        if AuraFonts.hasJakarta {
            return .custom("Plus Jakarta Sans", size: size).weight(weight)
        }
        return .system(size: size, weight: weight)
    }

    static let headlineXL = serif(32)
    static let headlineLG = serif(30)
    static let headlineMD = serif(24, .medium)
    static let headlineSM = serif(20, .medium)
    static let titleMD = sans(18, .semibold)
    static let bodyLG = sans(16)
    static let bodyMD = sans(14)
    static let bodySM = sans(12)
    static let labelLG = sans(14, .semibold)
    static let labelMD = sans(12, .semibold)
    static let labelSM = sans(10, .bold)
}

// MARK: - Reusable styles

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct PrimaryPillButtonStyle: ButtonStyle {
    var color: Color = Aura.primary
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.sans(16, .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Capsule().fill(color))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct SecondaryPillButtonStyle: ButtonStyle {
    var fill: Color = Aura.surfaceHigh
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.sans(14, .medium))
            .foregroundStyle(Aura.onSurface)
            .padding(.vertical, 14)
            .padding(.horizontal, 18)
            .background(Capsule().fill(fill))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

extension View {
    /// Level 1 resting card: clay surface + hairline outline, deep radius.
    func auraCard(_ fill: Color = Aura.surfaceLow, radius: CGFloat = Aura.radiusLG, padding: CGFloat = Aura.spaceMD) -> some View {
        self
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(Aura.hairline, lineWidth: 1)
            )
    }

    /// Level 2 floating surface with ultra-diffused ambient shadow.
    func floatingShadow() -> some View {
        shadow(color: Aura.softShadow, radius: 16, x: 0, y: 12)
    }
}
