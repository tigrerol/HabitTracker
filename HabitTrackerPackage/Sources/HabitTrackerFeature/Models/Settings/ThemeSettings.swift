import SwiftUI
import SwiftData

// MARK: - App Theme

public enum AppTheme: String, CaseIterable, Sendable {
    case sunstone
    case slate

    public var displayName: String {
        switch self {
        case .sunstone: return "Sunstone"
        case .slate: return "Slate"
        }
    }

    public var modeLabel: String {
        switch self {
        case .sunstone: return "Light"
        case .slate: return "Dark"
        }
    }

    public var tagline: String {
        switch self {
        case .sunstone: return "Warm and grounded"
        case .slate: return "Focused and deep"
        }
    }

    public var accentColor: Color {
        switch self {
        case .sunstone: return Color(hex: "C4702B") ?? .orange
        case .slate: return Color(hex: "7FC8A9") ?? .green
        }
    }

    public var accentHex: String {
        switch self {
        case .sunstone: return "C4702B"
        case .slate: return "7FC8A9"
        }
    }

    public var preferredColorScheme: ColorScheme {
        switch self {
        case .sunstone: return .light
        case .slate: return .dark
        }
    }

    /// Background color for theme preview rendering
    public var previewBackground: Color {
        switch self {
        case .sunstone: return Color(hex: "EDE3CE") ?? .white
        case .slate: return Color(hex: "0C1B2E") ?? .black
        }
    }

    /// Card surface for theme preview rendering
    public var previewSurface: Color {
        switch self {
        case .sunstone: return Color(hex: "FAF3E4") ?? .white
        case .slate: return Color(hex: "162840") ?? Color(white: 0.12)
        }
    }

    /// Primary text color for theme preview rendering
    public var previewTextPrimary: Color {
        switch self {
        case .sunstone: return Color(hex: "1A1717") ?? .black
        case .slate: return Color(hex: "EFEFEF") ?? .white
        }
    }

    /// Secondary text color for theme preview rendering
    public var previewTextSecondary: Color {
        switch self {
        case .sunstone: return (Color(hex: "1A1717") ?? .black).opacity(0.45)
        case .slate: return (Color(hex: "EFEFEF") ?? .white).opacity(0.45)
        }
    }
}

// MARK: - Theme Settings Model

@Model
public final class ThemeSettings {
    // MARK: - Properties

    public var accentColorHex: String
    public var lastModified: Date

    // MARK: - Initialization

    public init(accentColorHex: String = "C4702B") {
        self.accentColorHex = accentColorHex
        self.lastModified = Date()
    }

    // MARK: - Computed Properties

    public var accentColor: Color {
        Color(hex: accentColorHex) ?? AppTheme.sunstone.accentColor
    }
}

// MARK: - Theme Manager

@MainActor
@Observable
public final class ThemeManager {
    // MARK: - Singleton

    public static let shared = ThemeManager()

    // MARK: - Properties

    public private(set) var currentTheme: AppTheme = .sunstone
    public private(set) var currentAccentColor: Color = AppTheme.sunstone.accentColor
    public var preferredColorScheme: ColorScheme { currentTheme.preferredColorScheme }

    private var settings: ThemeSettings?
    private var modelContext: ModelContext?

    // MARK: - Available Themes

    public let availableThemes: [AppTheme] = AppTheme.allCases

    // MARK: - Initialization

    private init() {
        loadThemeSettings()
    }

    // MARK: - Public Methods

    public func setup(with context: ModelContext) {
        self.modelContext = context
        loadThemeSettings()
    }

    public func updateTheme(_ theme: AppTheme) {
        currentTheme = theme
        currentAccentColor = theme.accentColor
        saveAccentColor(theme.accentHex)
    }

    /// Legacy method — kept for compatibility; resolves to nearest theme
    public func updateAccentColor(_ color: Color) {
        if let hex = color.toHex() {
            updateAccentColor(hex: hex)
        }
    }

    public func updateAccentColor(hex: String) {
        // Map hex to the nearest theme or default to sunstone
        let matched = AppTheme.allCases.first { $0.accentHex.lowercased() == hex.lowercased() }
        updateTheme(matched ?? .sunstone)
    }

    // MARK: - Private Methods

    private func loadThemeSettings() {
        // Try to load from ModelContext first
        if let context = modelContext {
            let descriptor = FetchDescriptor<ThemeSettings>()
            if let existingSettings = try? context.fetch(descriptor).first {
                settings = existingSettings
                resolveTheme(from: existingSettings.accentColorHex)
                return
            }
        }

        // Fallback to UserDefaults
        if let savedHex = UserDefaults.standard.string(forKey: "accentColorHex") {
            resolveTheme(from: savedHex)
        }
    }

    private func resolveTheme(from hex: String) {
        let matched = AppTheme.allCases.first { $0.accentHex.lowercased() == hex.lowercased() }
        currentTheme = matched ?? .sunstone
        currentAccentColor = currentTheme.accentColor
    }

    private func saveAccentColor(_ hex: String) {
        UserDefaults.standard.set(hex, forKey: "accentColorHex")

        guard let context = modelContext else { return }

        if let existingSettings = settings {
            existingSettings.accentColorHex = hex
            existingSettings.lastModified = Date()
        } else {
            let newSettings = ThemeSettings(accentColorHex: hex)
            context.insert(newSettings)
            settings = newSettings
        }

        try? context.save()
    }
}

// MARK: - Theme Extension

extension Theme {
    @MainActor
    public static var dynamicAccent: Color {
        ThemeManager.shared.currentAccentColor
    }
}

