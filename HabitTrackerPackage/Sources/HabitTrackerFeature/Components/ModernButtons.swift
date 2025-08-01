import SwiftUI

// MARK: - Primary Action Button

public struct PrimaryButton: View {
    let title: String
    let action: () -> Void
    let isEnabled: Bool
    let isLoading: Bool
    
    public init(_ title: String, isEnabled: Bool = true, isLoading: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.isEnabled = isEnabled
        self.isLoading = isLoading
        self.action = action
    }
    
    public var body: some View {
        Button(action: {
            if isEnabled && !isLoading {
                HapticManager.trigger(.light)
                action()
            }
        }) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Text(title)
                        .customSubheadline()
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                Capsule()
                    .fill(isEnabled ? Theme.accent : Color.gray)
            )
        }
        .disabled(!isEnabled || isLoading)
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Secondary Action Button

public struct SecondaryButton: View {
    let title: String
    let action: () -> Void
    
    public init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }
    
    public var body: some View {
        Button(action: {
            HapticManager.trigger(.selection)
            action()
        }) {
            Text(title)
                .customSubheadline()
                .foregroundColor(Theme.accent)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    Capsule()
                        .stroke(Theme.accent, lineWidth: 2)
                )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Icon Button

public struct IconButton: View {
    let icon: String
    let title: String?
    let action: () -> Void
    let style: ButtonStyle
    
    public enum ButtonStyle {
        case primary
        case secondary
        case minimal
    }
    
    public init(icon: String, title: String? = nil, style: ButtonStyle = .primary, action: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.style = style
        self.action = action
    }
    
    public var body: some View {
        Button(action: {
            HapticManager.trigger(.light)
            action()
        }) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                
                if let title = title {
                    Text(title)
                        .customBody()
                }
            }
            .padding(.horizontal, title != nil ? 16 : 12)
            .padding(.vertical, 12)
            .foregroundColor(foregroundColor)
            .background(background)
        }
        .buttonStyle(ScaleButtonStyle())
    }
    
    private var foregroundColor: Color {
        switch style {
        case .primary:
            return .white
        case .secondary:
            return Theme.accent
        case .minimal:
            return Theme.text
        }
    }
    
    @ViewBuilder
    private var background: some View {
        switch style {
        case .primary:
            Capsule()
                .fill(Theme.accent)
        case .secondary:
            Capsule()
                .stroke(Theme.accent, lineWidth: 2)
        case .minimal:
            Capsule()
                .fill(Color.gray.opacity(0.1))
        }
    }
}

// MARK: - Floating Action Button

public struct FloatingActionButton: View {
    let icon: String
    let action: () -> Void
    
    public init(icon: String, action: @escaping () -> Void) {
        self.icon = icon
        self.action = action
    }
    
    public var body: some View {
        Button(action: {
            HapticManager.trigger(.medium)
            action()
        }) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Theme.accent, Theme.accent.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .shadow(color: Theme.accent.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(BounceButtonStyle())
    }
}

// MARK: - Scale Button Style

public struct ScaleButtonStyle: ButtonStyle {
    public init() {}
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Bounce Button Style

public struct BounceButtonStyle: ButtonStyle {
    public init() {}
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.5), value: configuration.isPressed)
    }
}

// MARK: - Animated Toggle

public struct AnimatedToggle: View {
    @Binding var isOn: Bool
    let label: String
    
    public init(_ label: String, isOn: Binding<Bool>) {
        self.label = label
        self._isOn = isOn
    }
    
    public var body: some View {
        HStack {
            Text(label)
                .customBody()
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(SwitchToggleStyle(tint: Theme.accent))
        }
        .sensoryFeedback(.selection, trigger: isOn)
    }
}