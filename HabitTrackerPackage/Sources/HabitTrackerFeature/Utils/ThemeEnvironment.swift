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
            .tint(themeManager.currentAccentColor)
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
            .tint(themeManager.currentAccentColor)
    }
}

// MARK: - Theme-Aware Button Styles

/// Prominent glass capsule tinted with the current accent — apply directly to Button
public struct DynamicPrimaryButtonStyle: PrimitiveButtonStyle {
    @Environment(ThemeManager.self) private var themeManager

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        Button(role: configuration.role) {
            configuration.trigger()
        } label: {
            configuration.label
                .padding(.horizontal, 8)
        }
        .buttonStyle(.glassProminent)
        .tint(themeManager.currentAccentColor)
    }
}

/// Plain glass capsule with accent-tinted label — apply directly to Button
public struct DynamicSecondaryButtonStyle: PrimitiveButtonStyle {
    @Environment(ThemeManager.self) private var themeManager

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        Button(role: configuration.role) {
            configuration.trigger()
        } label: {
            configuration.label
                .padding(.horizontal, 8)
        }
        .buttonStyle(.glass)
        .tint(themeManager.currentAccentColor)
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
                    .fill(Theme.hairline)
                    .frame(height: height)

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                themeManager.currentAccentColor,
                                themeManager.currentAccentColor.opacity(0.75)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * progress, height: height)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: progress)
            }
        }
        .frame(height: height)
    }
}
