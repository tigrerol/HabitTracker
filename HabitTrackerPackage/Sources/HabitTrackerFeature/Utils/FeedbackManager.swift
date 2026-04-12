import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if os(iOS)
import AudioToolbox
import AVFoundation
#endif

/// Manager for providing haptic and acoustic feedback
@MainActor
public final class FeedbackManager {
    public static let shared = FeedbackManager()

    /// UserDefaults key controlling whether timer completion plays an acoustic signal.
    public static let soundEnabledKey = "FeedbackManager.timerSoundEnabled"

    #if os(iOS)
    private var chimePlayer: AVAudioPlayer?
    #endif

    private init() {
        // Default to enabled if the user has never set it.
        if UserDefaults.standard.object(forKey: Self.soundEnabledKey) == nil {
            UserDefaults.standard.set(true, forKey: Self.soundEnabledKey)
        }
        #if os(iOS)
        prepareChimePlayer()
        #endif
    }

    /// Whether acoustic feedback for timer completion is enabled.
    public var isSoundEnabled: Bool {
        UserDefaults.standard.bool(forKey: Self.soundEnabledKey)
    }

    /// Provides haptic and acoustic feedback for timer completion
    public func timerCompleted() {
        // Haptic feedback - success pattern
        #if canImport(UIKit)
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.prepare()
        notificationFeedback.notificationOccurred(.success)
        #endif

        #if os(iOS)
        if isSoundEnabled {
            playChime()
        }
        #endif
    }

    /// Provides lighter haptic feedback for step completions
    public func stepCompleted() {
        #if canImport(UIKit)
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.prepare()
        impactFeedback.impactOccurred()
        #endif

        // Light system sound for steps - respects silent switch, intentional
        #if os(iOS)
        if isSoundEnabled {
            AudioServicesPlaySystemSound(SystemSoundID(1013))
        }
        #endif
    }

    #if os(iOS)
    // MARK: - Chime playback

    private func prepareChimePlayer() {
        guard let url = Bundle.module.url(forResource: "timer_chime", withExtension: "wav") else {
            return
        }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            chimePlayer = player
        } catch {
            chimePlayer = nil
        }
    }

    private func playChime() {
        // Configure session so the chime plays even if the ringer is muted,
        // while mixing with any other audio (music, podcasts) rather than stopping it.
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers, .duckOthers])
            try session.setActive(true, options: [])
        } catch {
            // If session setup fails, fall back to a system sound (respects mute).
            AudioServicesPlaySystemSound(SystemSoundID(1016))
            return
        }

        if chimePlayer == nil {
            prepareChimePlayer()
        }
        guard let player = chimePlayer else {
            AudioServicesPlaySystemSound(SystemSoundID(1016))
            return
        }
        player.currentTime = 0
        player.play()

        // Deactivate the session shortly after playback finishes so we stop
        // ducking other audio.
        let duration = player.duration
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64((duration + 0.1) * 1_000_000_000))
            await self?.deactivateAudioSession()
        }
    }

    private func deactivateAudioSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }
    #endif
}
