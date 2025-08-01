import SwiftUI

// MARK: - Modern Card Component

public struct ModernCard<Content: View>: View {
    let content: Content
    let style: CardStyle
    
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
                            colors: [.white.opacity(0.5), .clear],
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
                        .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                )
        }
    }
    
    private var shadowColor: Color {
        Color.black.opacity(style == .elevated ? 0.15 : 0.08)
    }
    
    private var shadowRadius: CGFloat {
        style == .elevated ? 15 : 8
    }
    
    private var shadowOffset: CGFloat {
        style == .elevated ? 8 : 4
    }
}

// MARK: - Habit Card Component

public struct HabitCard: View {
    let habit: Habit
    let isSelected: Bool
    let onTap: () -> Void
    
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
                        .foregroundColor(habit.swiftUIColor)
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
                            .foregroundColor(Theme.accent)
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