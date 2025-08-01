import SwiftUI
#if canImport(ActivityKit)
import ActivityKit
#endif

// MARK: - Public API
public struct HabitTrackerFeature {
    @MainActor
    public static func morningRoutineView() -> some View {
        MorningRoutineView()
    }
    
    // MARK: - Watch Connectivity
    #if canImport(WatchConnectivity)
    public static var watchConnectivityManager: WatchConnectivityManager {
        WatchConnectivityManager.shared
    }
    #endif
    
    // MARK: - Live Activities
    #if canImport(ActivityKit)
    @available(iOS 16.1, *)
    @MainActor
    public static var liveActivityManager: LiveActivityManager {
        LiveActivityManager.shared
    }
    #endif
}