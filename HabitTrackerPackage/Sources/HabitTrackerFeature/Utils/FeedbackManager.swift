import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if os(iOS)
import AudioToolbox
#endif

/// Manager for providing haptic and acoustic feedback
@MainActor
public final class FeedbackManager {
    public static let shared = FeedbackManager()
    
    private init() {}
    
    /// Provides haptic and acoustic feedback for timer completion
    public func timerCompleted() {
        // Haptic feedback - success pattern
        #if canImport(UIKit)
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.prepare()
        notificationFeedback.notificationOccurred(.success)
        #endif

        // Acoustic feedback using AudioServicesPlaySystemSound
        #if os(iOS)
        // Play system sound - 1016 is completion, 1013 is SMS received
        AudioServicesPlaySystemSound(SystemSoundID(1016))
        #endif
    }

    /// Provides lighter haptic feedback for step completions
    public func stepCompleted() {
        #if canImport(UIKit)
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.prepare()
        impactFeedback.impactOccurred()
        #endif
        
        // Light system sound for steps
        #if os(iOS)
        AudioServicesPlaySystemSound(SystemSoundID(1013))
        #endif
    }
}