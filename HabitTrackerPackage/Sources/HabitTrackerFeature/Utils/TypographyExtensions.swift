import SwiftUI

// MARK: - Typography ViewModifiers

public struct CustomTitleModifier: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .font(.system(.largeTitle, design: .rounded, weight: .bold))
            .foregroundColor(Theme.text)
    }
}

public struct CustomHeadlineModifier: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .font(.system(.headline, design: .rounded, weight: .semibold))
            .foregroundColor(Theme.text)
    }
}

public struct CustomSubheadlineModifier: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .font(.system(.subheadline, design: .rounded, weight: .medium))
            .foregroundColor(Theme.text)
    }
}

public struct CustomBodyModifier: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .font(.system(.body, design: .rounded))
            .foregroundColor(Theme.text)
    }
}

public struct CustomCaptionModifier: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .font(.system(.caption, design: .rounded))
            .foregroundColor(Theme.secondaryText)
    }
}

// MARK: - View Extensions

extension View {
    public func customTitle() -> some View {
        self.modifier(CustomTitleModifier())
    }
    
    public func customHeadline() -> some View {
        self.modifier(CustomHeadlineModifier())
    }
    
    public func customSubheadline() -> some View {
        self.modifier(CustomSubheadlineModifier())
    }
    
    public func customBody() -> some View {
        self.modifier(CustomBodyModifier())
    }
    
    public func customCaption() -> some View {
        self.modifier(CustomCaptionModifier())
    }
}