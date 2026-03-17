import SwiftUI

// MARK: - Dynamic Theme View

public struct DynamicThemeView<Content: View>: View {
    @State private var themeManager = ThemeManager.shared
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .environment(themeManager)
            .accentColor(themeManager.currentAccentColor)
            .preferredColorScheme(themeManager.preferredColorScheme)
    }
}

// MARK: - Theme-Aware Views

extension View {
    /// Apply the current dynamic accent color to this view
    public func dynamicAccentColor() -> some View {
        modifier(DynamicAccentColorModifier())
    }

    /// Wrap content with dynamic theme environment
    public func withDynamicTheme() -> some View {
        DynamicThemeView {
            self
        }
    }
}

// MARK: - Dynamic Accent Color Modifier

struct DynamicAccentColorModifier: ViewModifier {
    @Environment(ThemeManager.self) private var themeManager

    func body(content: Content) -> some View {
        content
            .accentColor(themeManager.currentAccentColor)
    }
}

// MARK: - Theme-Aware Button Styles

public struct DynamicPrimaryButtonStyle: ButtonStyle {
    @Environment(ThemeManager.self) private var themeManager

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(themeManager.currentAccentColor)
            .cornerRadius(10)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

public struct DynamicSecondaryButtonStyle: ButtonStyle {
    @Environment(ThemeManager.self) private var themeManager

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(themeManager.currentAccentColor)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(themeManager.currentAccentColor, lineWidth: 2)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Theme-Aware Progress View

public struct DynamicProgressView: View {
    let progress: Double
    let height: CGFloat
    @Environment(ThemeManager.self) private var themeManager

    public init(progress: Double, height: CGFloat = 8) {
        self.progress = progress
        self.height = height
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: height)

                Capsule()
                    .fill(themeManager.currentAccentColor)
                    .frame(width: geometry.size.width * progress, height: height)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: progress)
            }
        }
        .frame(height: height)
    }
}
