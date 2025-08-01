import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

public struct HapticManager {
    
    public enum FeedbackType: Sendable {
        case light
        case medium
        case heavy
        case success
        case warning
        case error
        case selection
    }
    
    public static func trigger(_ type: FeedbackType) {
        #if os(iOS)
        Task { @MainActor in
            switch type {
            case .light:
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
            case .medium:
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
            case .heavy:
                let impact = UIImpactFeedbackGenerator(style: .heavy)
                impact.impactOccurred()
            case .success:
                let notification = UINotificationFeedbackGenerator()
                notification.notificationOccurred(.success)
            case .warning:
                let notification = UINotificationFeedbackGenerator()
                notification.notificationOccurred(.warning)
            case .error:
                let notification = UINotificationFeedbackGenerator()
                notification.notificationOccurred(.error)
            case .selection:
                let selection = UISelectionFeedbackGenerator()
                selection.selectionChanged()
            }
        }
        #endif
    }
}

// SwiftUI Integration
extension View {
    public func hapticFeedback(_ type: HapticManager.FeedbackType, trigger: some Equatable) -> some View {
        self.onChange(of: trigger) { _, _ in
            HapticManager.trigger(type)
        }
    }
}