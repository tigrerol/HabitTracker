import SwiftUI

// MARK: - Geometry Effect Identifiers

/// Centralized namespace for matched geometry effect IDs
public enum GeometryEffectID {
    // Template Selection Effects
    case templateCard(templateId: UUID)
    case templateTitle(templateId: UUID)
    case templateProgress(templateId: UUID)
    case templatePlayButton(templateId: UUID)
    
    // Routine Execution Effects
    case routineHeader
    case routineProgress
    case routineTitle
    case currentHabitCard
    
    // Habit Interaction Effects
    case habitCard(habitId: UUID)
    case habitTitle(habitId: UUID)
    case habitProgress(habitId: UUID)
    case habitIcon(habitId: UUID)
    
    // Settings & Navigation Effects
    case settingsButton
    case backButton
    case floatingActionButton
    
    // Theme Customization Effects
    case colorPicker
    case selectedColor
    case themePreview
    
    // Modal & Sheet Effects
    case modalBackground
    case sheetHandle
    
    var id: String {
        switch self {
        case .templateCard(let templateId):
            return "template-card-\(templateId.uuidString)"
        case .templateTitle(let templateId):
            return "template-title-\(templateId.uuidString)"
        case .templateProgress(let templateId):
            return "template-progress-\(templateId.uuidString)"
        case .templatePlayButton(let templateId):
            return "template-play-\(templateId.uuidString)"
        case .routineHeader:
            return "routine-header"
        case .routineProgress:
            return "routine-progress"
        case .routineTitle:
            return "routine-title"
        case .currentHabitCard:
            return "current-habit-card"
        case .habitCard(let habitId):
            return "habit-card-\(habitId.uuidString)"
        case .habitTitle(let habitId):
            return "habit-title-\(habitId.uuidString)"
        case .habitProgress(let habitId):
            return "habit-progress-\(habitId.uuidString)"
        case .habitIcon(let habitId):
            return "habit-icon-\(habitId.uuidString)"
        case .settingsButton:
            return "settings-button"
        case .backButton:
            return "back-button"
        case .floatingActionButton:
            return "floating-action-button"
        case .colorPicker:
            return "color-picker"
        case .selectedColor:
            return "selected-color"
        case .themePreview:
            return "theme-preview"
        case .modalBackground:
            return "modal-background"
        case .sheetHandle:
            return "sheet-handle"
        }
    }
}

// MARK: - Matched Geometry View Modifiers

extension View {
    /// Apply matched geometry effect with consistent animation timing
    public func matchedGeometry(
        id: GeometryEffectID,
        in namespace: Namespace.ID,
        properties: MatchedGeometryProperties = .frame,
        anchor: UnitPoint = .center,
        isSource: Bool = true
    ) -> some View {
        self.matchedGeometryEffect(
            id: id.id,
            in: namespace,
            properties: properties,
            anchor: anchor,
            isSource: isSource
        )
    }
    
    /// Apply hero animation with smooth spring transition
    public func heroTransition() -> some View {
        self.animation(.spring(response: 0.6, dampingFraction: 0.8), value: UUID())
    }
    
    /// Apply card elevation animation for interactive elements
    public func cardElevation(isPressed: Bool = false) -> some View {
        self
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .shadow(
                color: .black.opacity(isPressed ? 0.1 : 0.05),
                radius: isPressed ? 2 : 4,
                x: 0,
                y: isPressed ? 1 : 2
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
    }
}

// MARK: - Animation Presets

public struct AnimationPresets {
    /// Smooth spring animation for matched geometry effects
    public static let smoothSpring = Animation.spring(response: 0.6, dampingFraction: 0.8)
    
    /// Quick spring for button interactions
    public static let quickSpring = Animation.spring(response: 0.3, dampingFraction: 0.7)
    
    /// Bouncy spring for playful interactions
    public static let bouncySpring = Animation.spring(response: 0.4, dampingFraction: 0.6)
    
    /// Fluid ease-in-out for smooth transitions
    public static let fluidEase = Animation.easeInOut(duration: 0.5)
    
    /// Snappy transition for immediate feedback
    public static let snappy = Animation.easeOut(duration: 0.2)
}

// MARK: - Transition Effects

public struct TransitionEffects {
    /// Slide in from the right with fade
    nonisolated(unsafe) public static let slideInFromRight = AnyTransition.asymmetric(
        insertion: .move(edge: .trailing).combined(with: .opacity),
        removal: .move(edge: .leading).combined(with: .opacity)
    )
    
    /// Slide in from the bottom with scale
    nonisolated(unsafe) public static let slideInFromBottom = AnyTransition.asymmetric(
        insertion: .move(edge: .bottom).combined(with: .scale(scale: 0.9)),
        removal: .move(edge: .bottom).combined(with: .opacity)
    )
    
    /// Scale and fade transition
    nonisolated(unsafe) public static let scaleAndFade = AnyTransition.scale(scale: 0.8).combined(with: .opacity)
    
    /// Push transition for navigation-like feel
    nonisolated(unsafe) public static let push = AnyTransition.asymmetric(
        insertion: .move(edge: .trailing),
        removal: .move(edge: .leading)
    )
    
    /// Modal presentation with background blur
    nonisolated(unsafe) public static let modalPresentation = AnyTransition.asymmetric(
        insertion: .move(edge: .bottom).combined(with: .opacity),
        removal: .move(edge: .bottom).combined(with: .opacity)
    )
}

// MARK: - Interactive Animation State

@MainActor
@Observable
public final class InteractionState {
    public var pressedItems: Set<String> = []
    public var selectedItems: Set<String> = []
    public var highlightedItems: Set<String> = []
    
    public init() {}
    
    public func setPressed(_ id: String, isPressed: Bool) {
        if isPressed {
            pressedItems.insert(id)
        } else {
            pressedItems.remove(id)
        }
    }
    
    public func setSelected(_ id: String, isSelected: Bool) {
        if isSelected {
            selectedItems.insert(id)
        } else {
            selectedItems.remove(id)
        }
    }
    
    public func setHighlighted(_ id: String, isHighlighted: Bool) {
        if isHighlighted {
            highlightedItems.insert(id)
        } else {
            highlightedItems.remove(id)
        }
    }
    
    public func isPressed(_ id: String) -> Bool {
        pressedItems.contains(id)
    }
    
    public func isSelected(_ id: String) -> Bool {
        selectedItems.contains(id)
    }
    
    public func isHighlighted(_ id: String) -> Bool {
        highlightedItems.contains(id)
    }
}

// MARK: - Enhanced Card View with Geometry Effects

public struct AnimatedCard<Content: View>: View {
    let content: Content
    let geometryID: GeometryEffectID?
    let namespace: Namespace.ID?
    let isPressed: Bool
    let onTap: (() -> Void)?
    
    @Environment(\.themeManager) private var themeManager
    
    public init(
        geometryID: GeometryEffectID? = nil,
        namespace: Namespace.ID? = nil,
        isPressed: Bool = false,
        onTap: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.geometryID = geometryID
        self.namespace = namespace
        self.isPressed = isPressed
        self.onTap = onTap
    }
    
    public var body: some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.regularMaterial)
                    .shadow(
                        color: themeManager.currentAccentColor.opacity(0.1),
                        radius: isPressed ? 2 : 6,
                        x: 0,
                        y: isPressed ? 1 : 3
                    )
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(AnimationPresets.quickSpring, value: isPressed)
            .if(geometryID != nil && namespace != nil) { view in
                view.matchedGeometry(id: geometryID!, in: namespace!)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if let onTap = onTap {
                    HapticManager.trigger(.light)
                    onTap()
                }
            }
    }
}

// MARK: - Conditional View Modifier

extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}