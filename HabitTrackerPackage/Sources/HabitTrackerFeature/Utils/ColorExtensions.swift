import Foundation
import SwiftUI

// MARK: - Color Extensions

extension Color {
    /// Initialize Color from hex string
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        
        // Check if the scanner was successful
        guard Scanner(string: hex).scanHexInt64(&int) else {
            return nil
        }
        
        // Ensure hex string is not empty
        guard !hex.isEmpty else {
            return nil
        }
        
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        
        // Ensure values are valid before converting to Double
        let red = Double(r) / 255.0
        let green = Double(g) / 255.0
        let blue = Double(b) / 255.0
        let opacity = Double(a) / 255.0
        
        // Validate that values are not NaN
        guard !red.isNaN && !green.isNaN && !blue.isNaN && !opacity.isNaN else {
            return nil
        }
        
        self.init(
            .sRGB,
            red: red,
            green: green,
            blue: blue,
            opacity: opacity
        )
    }
}

// MARK: - Color Encoding/Decoding Utilities

public struct ColorUtils {
    
    /// Encode a Color to Data for persistence
    public static func encodeColor(_ color: Color) -> Data {
        do {
            let resolved = color.resolve(in: .init())
            let colorInfo = ColorInfo(
                red: resolved.red,
                green: resolved.green,
                blue: resolved.blue,
                opacity: resolved.opacity
            )
            return try JSONEncoder().encode(colorInfo)
        } catch {
            // Fallback to blue
            let fallback = ColorInfo(red: 0.0, green: 0.5, blue: 1.0, opacity: 1.0)
            return (try? JSONEncoder().encode(fallback)) ?? Data()
        }
    }
    
    /// Decode a Color from Data
    public static func decodeColor(from data: Data) -> Color {
        do {
            let colorInfo = try JSONDecoder().decode(ColorInfo.self, from: data)
            return Color(
                red: Double(colorInfo.red),
                green: Double(colorInfo.green),
                blue: Double(colorInfo.blue),
                opacity: Double(colorInfo.opacity)
            )
        } catch {
            return .blue
        }
    }
    
    /// Internal color info structure for encoding/decoding
    private struct ColorInfo: Codable {
        let red: Float
        let green: Float
        let blue: Float
        let opacity: Float
    }
}

// MARK: - Modern Theme System

public struct Theme {
    
    // MARK: - Color Palette
    public struct Colors {
        // Primary Backgrounds
        public static let primaryBackground = Color(hex: "F7F7F7")!     // Off-white
        public static let darkPrimaryBackground = Color(hex: "1A202C")! // Deep blue-grey
        
        // Card Backgrounds
        public static let cardBackground = Color.white
        public static let darkCardBackground = Color(hex: "2D3748")!    // Lighter dark
        
        // Accent Colors - Choose one as primary
        public static let accentTeal = Color(hex: "4FD1C5")!      // Energetic primary
        public static let accentOrange = Color(hex: "F56565")!    // Warm alerts
        public static let accentLavender = Color(hex: "9F7AEA")!  // Soothing secondary
        public static let accentGreen = Color(hex: "48BB78")!     // Success states
        
        // Text Colors
        public static let primaryText = Color.black
        public static let darkPrimaryText = Color.white
        public static let secondaryText = Color.gray
        public static let darkSecondaryText = Color(hex: "A0AEC0")!
    }
    
    // MARK: - Dynamic Colors (Auto Light/Dark Mode)
    public static func dynamicColor(light: Color, dark: Color) -> Color {
        return Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
    
    // Semantic Colors
    public static let background = dynamicColor(
        light: Colors.primaryBackground,
        dark: Colors.darkPrimaryBackground
    )
    
    public static let cardBackground = dynamicColor(
        light: Colors.cardBackground,
        dark: Colors.darkCardBackground
    )
    
    public static let text = dynamicColor(
        light: Colors.primaryText,
        dark: Colors.darkPrimaryText
    )
    
    public static let secondaryText = dynamicColor(
        light: Colors.secondaryText,
        dark: Colors.darkSecondaryText
    )
    
    // Primary accent - customize based on brand preference
    public static let accent = Colors.accentTeal
}