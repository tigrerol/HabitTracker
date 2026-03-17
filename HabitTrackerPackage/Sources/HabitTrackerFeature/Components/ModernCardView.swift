import SwiftUI

// MARK: - Modern Card Component

public struct ModernCard<Content: View>: View {
    let content: Content
    let style: CardStyle
    
    @Environment(ThemeManager.self) private var themeManager
    
    public enum CardStyle {
        case standard
        case frosted
        case elevated
    }
    
    public init(style: CardStyle = .standard, @ViewBuilder content: () -> Content) {
        self.style = style
        self.content = content()
    }
    
    public var body: some View {
        ZStack {
            backgroundView
            content
                .padding(20) // Generous padding for premium feel
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: shadowOffset)
    }
    
    @ViewBuilder
    private var backgroundView: some View {
        switch style {
        case .standard:
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Theme.cardBackground)
        
        case .frosted:
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
                
                // Subtle inner glow for depth
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                themeManager.currentAccentColor.opacity(0.3),
                                .white.opacity(0.5),
                                .clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
        
        case .elevated:
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Theme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    themeManager.currentAccentColor.opacity(0.2),
                                    themeManager.currentAccentColor.opacity(0.05),
                                    Color.gray.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        }
    }
    
    private var shadowColor: Color {
        switch style {
        case .elevated: Color.black.opacity(0.12)
        case .standard: Color.black.opacity(0.06)
        case .frosted: Color.black.opacity(0.04)
        }
    }

    private var shadowRadius: CGFloat {
        switch style {
        case .elevated: 20
        case .standard: 10
        case .frosted: 6
        }
    }

    private var shadowOffset: CGFloat {
        switch style {
        case .elevated: 6
        case .standard: 3
        case .frosted: 2
        }
    }
}

// MARK: - Habit Card Component

public struct HabitCard: View {
    let habit: Habit
    let isSelected: Bool
    let onTap: () -> Void

    @Environment(ThemeManager.self) private var themeManager

    public init(habit: Habit, isSelected: Bool = false, onTap: @escaping () -> Void) {
        self.habit = habit
        self.isSelected = isSelected
        self.onTap = onTap
    }
    
    public var body: some View {
        Button(action: onTap) {
            ModernCard(style: isSelected ? .elevated : .standard) {
                HStack(spacing: 16) {
                    // Habit Icon
                    Image(systemName: habit.type.iconName)
                        .font(.title2)
                        .foregroundStyle(habit.swiftUIColor)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(habit.swiftUIColor.opacity(0.1))
                        )
                    
                    // Habit Info
                    VStack(alignment: .leading, spacing: 4) {
                        Text(habit.name)
                            .customSubheadline()
                            .lineLimit(1)
                        
                        Text(habit.type.description)
                            .customCaption()
                    }
                    
                    Spacer()
                    
                    // Selection Indicator
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(themeManager.currentAccentColor)
                            .font(.title3)
                    }
                }
            }
        }
        .buttonStyle(ModernButtonStyle())
        .sensoryFeedback(.selection, trigger: isSelected)
    }
}

// MARK: - Modern Button Style

public struct ModernButtonStyle: ButtonStyle {
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
