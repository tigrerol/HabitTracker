import SwiftUI
import SwiftData

// MARK: - Theme Settings Model

@Model
public final class ThemeSettings {
    // MARK: - Properties
    
    public var accentColorHex: String
    public var lastModified: Date
    
    // MARK: - Initialization
    
    public init(accentColorHex: String = "4FD1C5") { // Default to teal
        self.accentColorHex = accentColorHex
        self.lastModified = Date()
    }
    
    // MARK: - Computed Properties
    
    public var accentColor: Color {
        Color(hex: accentColorHex) ?? Theme.Colors.accentTeal
    }
}

// MARK: - Theme Manager

@MainActor
@Observable
public final class ThemeManager {
    // MARK: - Singleton
    
    public static let shared = ThemeManager()
    
    // MARK: - Properties
    
    public private(set) var currentAccentColor: Color = Theme.Colors.accentTeal
    private var settings: ThemeSettings?
    private var modelContext: ModelContext?
    
    // MARK: - Available Colors
    
    public let availableColors: [(name: String, color: Color)] = [
        ("Teal", Theme.Colors.accentTeal),
        ("Orange", Theme.Colors.accentOrange),
        ("Red", Theme.Colors.accentRed),
        ("Lavender", Theme.Colors.accentLavender),
        ("Green", Theme.Colors.accentGreen),
        ("Blue", Color(hex: "3182CE")!),
        ("Pink", Color(hex: "ED64A6")!),
        ("Purple", Color(hex: "805AD5")!),
        ("Yellow", Color(hex: "ECC94B")!),
        ("Indigo", Color(hex: "5A67D8")!)
    ]
    
    // MARK: - Initialization
    
    private init() {
        loadThemeSettings()
    }
    
    // MARK: - Public Methods
    
    public func setup(with context: ModelContext) {
        self.modelContext = context
        loadThemeSettings()
    }
    
    public func updateAccentColor(_ color: Color) {
        currentAccentColor = color
        
        // Save to persistent storage
        if let hexString = color.toHex() {
            saveAccentColor(hexString)
        }
        
        // Update dynamic theme
        updateDynamicTheme()
    }
    
    public func updateAccentColor(hex: String) {
        if let color = Color(hex: hex) {
            updateAccentColor(color)
        }
    }
    
    // MARK: - Private Methods
    
    private func loadThemeSettings() {
        // Try to load from ModelContext first
        if let context = modelContext {
            let descriptor = FetchDescriptor<ThemeSettings>()
            if let existingSettings = try? context.fetch(descriptor).first {
                settings = existingSettings
                currentAccentColor = existingSettings.accentColor
                return
            }
        }
        
        // Fallback to UserDefaults
        if let savedHex = UserDefaults.standard.string(forKey: "accentColorHex"),
           let color = Color(hex: savedHex) {
            currentAccentColor = color
        }
    }
    
    private func saveAccentColor(_ hex: String) {
        // Save to UserDefaults immediately
        UserDefaults.standard.set(hex, forKey: "accentColorHex")
        
        // Save to SwiftData if available
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
    
    private func updateDynamicTheme() {
        // UI updates are automatic with @Observable
        // No manual triggering needed
    }
}

// MARK: - Theme Extension

extension Theme {
    /// Dynamic accent color that responds to user selection
    @MainActor
    public static var dynamicAccent: Color {
        ThemeManager.shared.currentAccentColor
    }
}

// MARK: - Color to Hex Extension

extension Color {
    func toHex() -> String? {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        guard uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return nil
        }
        
        let rgb = Int(red * 255) << 16 | Int(green * 255) << 8 | Int(blue * 255)
        return String(format: "%06X", rgb)
    }
}