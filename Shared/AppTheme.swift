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
        switch self {
        case .mint: Color(red: 0.10, green: 0.55, blue: 0.50)
        case .peach: Color(red: 0.85, green: 0.43, blue: 0.32)
        case .sky: Color(red: 0.16, green: 0.45, blue: 0.75)
        case .lavender: Color(red: 0.45, green: 0.36, blue: 0.72)
        }
    }

    var secondary: Color {
        switch self {
        case .mint: Color(red: 0.48, green: 0.78, blue: 0.65)
        case .peach: Color(red: 0.96, green: 0.67, blue: 0.45)
        case .sky: Color(red: 0.44, green: 0.73, blue: 0.88)
        case .lavender: Color(red: 0.75, green: 0.62, blue: 0.86)
        }
    }

    var background: Color {
        switch self {
        case .mint: Color(red: 0.93, green: 0.98, blue: 0.95)
        case .peach: Color(red: 1.00, green: 0.96, blue: 0.92)
        case .sky: Color(red: 0.93, green: 0.97, blue: 1.00)
        case .lavender: Color(red: 0.97, green: 0.95, blue: 1.00)
        }
    }

    var surface: Color {
        switch self {
        case .mint: Color(red: 0.98, green: 1.00, blue: 0.98)
        case .peach: Color(red: 1.00, green: 0.99, blue: 0.96)
        case .sky: Color(red: 0.98, green: 0.99, blue: 1.00)
        case .lavender: Color(red: 0.99, green: 0.98, blue: 1.00)
        }
    }

    var glow: Color {
        switch self {
        case .mint: Color(red: 0.78, green: 0.94, blue: 0.84)
        case .peach: Color(red: 1.00, green: 0.82, blue: 0.67)
        case .sky: Color(red: 0.76, green: 0.90, blue: 1.00)
        case .lavender: Color(red: 0.89, green: 0.81, blue: 1.00)
        }
    }
}

@MainActor
final class ThemeController: ObservableObject {
    @Published var selectedTheme: AppTheme {
        didSet {
            UserDefaults.standard.set(selectedTheme.rawValue, forKey: storageKey)
        }
    }

    private let storageKey = "gangbao.theme"

    init() {
        let rawValue = UserDefaults.standard.string(forKey: storageKey)
        selectedTheme = rawValue.flatMap(AppTheme.init(rawValue:)) ?? .mint
    }
}
