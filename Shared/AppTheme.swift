import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case mint
    case peach
    case sky
    case lavender

    var id: String { rawValue }

    var localizedName: LocalizedStringKey {
        switch self {
        case .mint: "theme.mint"
        case .peach: "theme.peach"
        case .sky: "theme.sky"
        case .lavender: "theme.lavender"
        }
    }

    var primary: Color {
        adaptiveColor(
            light: lightPrimaryComponents,
            dark: darkPrimaryComponents
        )
    }

    var secondary: Color {
        adaptiveColor(
            light: lightSecondaryComponents,
            dark: darkSecondaryComponents
        )
    }

    var background: Color {
        adaptiveColor(
            light: lightBackgroundComponents,
            dark: darkBackgroundComponents
        )
    }

    var surface: Color {
        adaptiveColor(
            light: lightSurfaceComponents,
            dark: darkSurfaceComponents
        )
    }

    var glow: Color {
        adaptiveColor(
            light: lightGlowComponents,
            dark: darkGlowComponents
        )
    }

    private var lightPrimaryComponents: RGBComponents {
        switch self {
        case .mint: RGBComponents(0.09, 0.54, 0.49)
        case .peach: RGBComponents(0.80, 0.39, 0.30)
        case .sky: RGBComponents(0.15, 0.43, 0.70)
        case .lavender: RGBComponents(0.43, 0.34, 0.68)
        }
    }

    private var darkPrimaryComponents: RGBComponents {
        switch self {
        case .mint: RGBComponents(0.30, 0.78, 0.70)
        case .peach: RGBComponents(0.96, 0.56, 0.43)
        case .sky: RGBComponents(0.40, 0.70, 0.96)
        case .lavender: RGBComponents(0.68, 0.57, 0.94)
        }
    }

    private var lightSecondaryComponents: RGBComponents {
        switch self {
        case .mint: RGBComponents(0.46, 0.76, 0.64)
        case .peach: RGBComponents(0.93, 0.64, 0.45)
        case .sky: RGBComponents(0.43, 0.71, 0.86)
        case .lavender: RGBComponents(0.72, 0.60, 0.84)
        }
    }

    private var darkSecondaryComponents: RGBComponents {
        switch self {
        case .mint: RGBComponents(0.18, 0.48, 0.43)
        case .peach: RGBComponents(0.54, 0.30, 0.25)
        case .sky: RGBComponents(0.20, 0.42, 0.60)
        case .lavender: RGBComponents(0.39, 0.31, 0.58)
        }
    }

    private var lightBackgroundComponents: RGBComponents {
        switch self {
        case .mint: RGBComponents(0.94, 0.98, 0.96)
        case .peach: RGBComponents(1.00, 0.97, 0.94)
        case .sky: RGBComponents(0.94, 0.98, 1.00)
        case .lavender: RGBComponents(0.97, 0.96, 1.00)
        }
    }

    private var darkBackgroundComponents: RGBComponents {
        switch self {
        case .mint: RGBComponents(0.06, 0.12, 0.12)
        case .peach: RGBComponents(0.14, 0.09, 0.08)
        case .sky: RGBComponents(0.06, 0.10, 0.15)
        case .lavender: RGBComponents(0.10, 0.08, 0.15)
        }
    }

    private var lightSurfaceComponents: RGBComponents {
        switch self {
        case .mint: RGBComponents(0.98, 1.00, 0.99)
        case .peach: RGBComponents(1.00, 0.99, 0.97)
        case .sky: RGBComponents(0.98, 0.995, 1.00)
        case .lavender: RGBComponents(0.99, 0.985, 1.00)
        }
    }

    private var darkSurfaceComponents: RGBComponents {
        switch self {
        case .mint: RGBComponents(0.11, 0.19, 0.18)
        case .peach: RGBComponents(0.22, 0.14, 0.12)
        case .sky: RGBComponents(0.11, 0.17, 0.24)
        case .lavender: RGBComponents(0.17, 0.14, 0.24)
        }
    }

    private var lightGlowComponents: RGBComponents {
        switch self {
        case .mint: RGBComponents(0.80, 0.94, 0.86)
        case .peach: RGBComponents(1.00, 0.84, 0.70)
        case .sky: RGBComponents(0.78, 0.91, 1.00)
        case .lavender: RGBComponents(0.90, 0.83, 1.00)
        }
    }

    private var darkGlowComponents: RGBComponents {
        switch self {
        case .mint: RGBComponents(0.12, 0.44, 0.39)
        case .peach: RGBComponents(0.60, 0.25, 0.18)
        case .sky: RGBComponents(0.13, 0.34, 0.60)
        case .lavender: RGBComponents(0.32, 0.24, 0.62)
        }
    }

    private func adaptiveColor(light: RGBComponents, dark: RGBComponents) -> Color {
        #if os(iOS)
        Color(UIColor { traitCollection in
            let components = traitCollection.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: components.red, green: components.green, blue: components.blue, alpha: 1)
        })
        #else
        Color(red: light.red, green: light.green, blue: light.blue)
        #endif
    }
}

enum ThemeColorSchemePreference: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var localizedName: LocalizedStringKey {
        switch self {
        case .system: "appearance.system"
        case .light: "appearance.light"
        case .dark: "appearance.dark"
        }
    }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

private struct RGBComponents {
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat

    init(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat) {
        self.red = red
        self.green = green
        self.blue = blue
    }
}

@MainActor
final class ThemeController: ObservableObject {
    @Published var selectedTheme: AppTheme {
        didSet {
            UserDefaults.standard.set(selectedTheme.rawValue, forKey: themeStorageKey)
        }
    }

    @Published var colorSchemePreference: ThemeColorSchemePreference {
        didSet {
            UserDefaults.standard.set(colorSchemePreference.rawValue, forKey: colorSchemeStorageKey)
        }
    }

    private let themeStorageKey = "gangbao.theme"
    private let colorSchemeStorageKey = "gangbao.colorSchemePreference"

    init() {
        let themeRawValue = UserDefaults.standard.string(forKey: themeStorageKey)
        let colorSchemeRawValue = UserDefaults.standard.string(forKey: colorSchemeStorageKey)
        selectedTheme = themeRawValue.flatMap(AppTheme.init(rawValue:)) ?? .mint
        colorSchemePreference = colorSchemeRawValue.flatMap(ThemeColorSchemePreference.init(rawValue:)) ?? .system
    }
}
