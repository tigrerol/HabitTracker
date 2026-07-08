import SwiftUI

/// Shared color palette for conditional-habit options, indexed by option position.
/// Single source of truth for the row views that render option trees.
enum ConditionalOptionPalette {
    static let colors: [Color] = [.blue, .green, .orange, .purple, .red, .pink, .yellow, .cyan]

    static func color(at index: Int) -> Color {
        colors[index % colors.count]
    }
}
