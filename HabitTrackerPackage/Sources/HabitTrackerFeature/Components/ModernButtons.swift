import SwiftUI

// MARK: - Primary Action Button

/// Prominent Liquid Glass capsule button tinted with the current accent color
public struct PrimaryButton: View {
    let title: String
    let action: () -> Void
    let isEnabled: Bool
    let isLoading: Bool
    @Environment(ThemeManager.self) private var themeManager

    public init(_ title: String, isEnabled: Bool = true, isLoading: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.isEnabled = isEnabled
        self.isLoading = isLoading
        self.action = action
    }

    public var body: some View {
        Button {
            if isEnabled && !isLoading {
                HapticManager.trigger(.light)
                action()
            }
        } label: {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.8)
                } else {
                    Text(title)
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 38)
        }
        .buttonStyle(.glassProminent)
        .tint(isEnabled ? themeManager.currentAccentColor : .gray)
        .disabled(!isEnabled || isLoading)
    }
}

// MARK: - Secondary Action Button

/// Liquid Glass capsule button with accent-tinted label
public struct SecondaryButton: View {
    let title: String
    let action: () -> Void
    @Environment(ThemeManager.self) private var themeManager

    public init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    public var body: some View {
        Button {
            HapticManager.trigger(.selection)
            action()
        } label: {
            Text(title)
                .font(.system(.headline, design: .rounded, weight: .medium))
                .foregroundStyle(themeManager.currentAccentColor)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 38)
        }
        .buttonStyle(.glass)
    }
}

// MARK: - Icon Button

public struct IconButton: View {
    let icon: String
    let title: String?
    let action: () -> Void
    let style: ButtonStyle
    @Environment(ThemeManager.self) private var themeManager

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
        Button {
            HapticManager.trigger(.light)
            action()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.subheadline.weight(.semibold))

                if let title = title {
                    Text(title)
                        .font(.system(.body, design: .rounded))
                }
            }
            .padding(.horizontal, title != nil ? 4 : 0)
        }
        .modifier(IconButtonGlassStyle(style: style, accent: themeManager.currentAccentColor))
    }
}

private struct IconButtonGlassStyle: ViewModifier {
    let style: IconButton.ButtonStyle
    let accent: Color

    func body(content: Content) -> some View {
        switch style {
        case .primary:
            content
                .buttonStyle(.glassProminent)
                .tint(accent)
        case .secondary:
            content
                .buttonStyle(.glass)
                .tint(accent)
        case .minimal:
            content
                .buttonStyle(.glass)
                .tint(.primary)
        }
    }
}

// MARK: - Floating Action Button

/// Circular prominent glass button for the main screen action
public struct FloatingActionButton: View {
    let icon: String
    let action: () -> Void
    @Environment(ThemeManager.self) private var themeManager

    public init(icon: String, action: @escaping () -> Void) {
        self.icon = icon
        self.action = action
    }

    public var body: some View {
        Button {
            HapticManager.trigger(.medium)
            action()
        } label: {
            Image(systemName: icon)
                .font(.title2.weight(.semibold))
                .frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(.glassProminent)
        .buttonBorderShape(.circle)
        .tint(themeManager.currentAccentColor)
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
    @Environment(ThemeManager.self) private var themeManager

    public init(_ label: String, isOn: Binding<Bool>) {
        self.label = label
        self._isOn = isOn
    }

    public var body: some View {
        HStack {
            Text(label)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(Theme.text)

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(SwitchToggleStyle(tint: themeManager.currentAccentColor))
        }
        .sensoryFeedback(.selection, trigger: isOn)
    }
}
