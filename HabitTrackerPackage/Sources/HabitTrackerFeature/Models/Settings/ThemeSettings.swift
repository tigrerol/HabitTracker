import SwiftUI

// MARK: - Appearance Mode

public enum AppearanceMode: String, CaseIterable, Sendable {
    case system
    case light
    case dark

    public var displayName: String {
        switch self {
        case .system: return "Auto"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    public var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }

    /// nil follows the system setting
    public var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

// MARK: - Accent Preset

public struct AccentPreset: Identifiable, Equatable, Sendable {
    public let name: String
    public let hex: String

    public var id: String { hex }
    public var color: Color { Color(hex: hex) ?? Theme.Colors.accentTeal }

    public static let all: [AccentPreset] = [
        AccentPreset(name: "Teal", hex: "2B8C84"),
        AccentPreset(name: "Amber", hex: "C4702B"),
        AccentPreset(name: "Mint", hex: "7FC8A9"),
        AccentPreset(name: "Lavender", hex: "9F7AEA"),
        AccentPreset(name: "Coral", hex: "F56565"),
        AccentPreset(name: "Ocean", hex: "3A7BD5"),
    ]

    public static let `default` = all[0]
}

// MARK: - Theme Manager

@MainActor
@Observable
public final class ThemeManager {
    // MARK: - Singleton

    public static let shared = ThemeManager()

    // MARK: - Properties

    public private(set) var accentHex: String
    public private(set) var currentAccentColor: Color
    public private(set) var appearanceMode: AppearanceMode

    /// nil follows the system setting
    public var preferredColorScheme: ColorScheme? { appearanceMode.colorScheme }

    // MARK: - Persistence Keys

    private static let accentKey = "accentColorHex"
    private static let appearanceKey = "appearanceMode"

    // MARK: - Initialization

    private init() {
        let savedHex = UserDefaults.standard.string(forKey: Self.accentKey) ?? AccentPreset.default.hex
        self.accentHex = savedHex
        self.currentAccentColor = Color(hex: savedHex) ?? AccentPreset.default.color

        let savedMode = UserDefaults.standard.string(forKey: Self.appearanceKey) ?? ""
        self.appearanceMode = AppearanceMode(rawValue: savedMode) ?? .system
    }

    // MARK: - Public Methods

    public func updateAccentColor(hex: String) {
        guard let color = Color(hex: hex) else { return }
        accentHex = hex
        currentAccentColor = color
        UserDefaults.standard.set(hex, forKey: Self.accentKey)
    }

    public func updateAppearanceMode(_ mode: AppearanceMode) {
        appearanceMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: Self.appearanceKey)
    }
}

// MARK: - Theme Extension

extension Theme {
    @MainActor
    public static var dynamicAccent: Color {
        ThemeManager.shared.currentAccentColor
    }
}
