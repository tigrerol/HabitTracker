import SwiftUI
#if canImport(ActivityKit)
import ActivityKit
#endif

// MARK: - Public API
public struct HabitTrackerFeature {
    @MainActor
    public static func morningRoutineView() -> some View {
        MorningRoutineView()
            .withDynamicTheme()
    }
    
    @MainActor
    public static func themeCustomizationView() -> some View {
        ThemeCustomizationView()
            .withDynamicTheme()
    }
    
    // MARK: - Watch Connectivity
    #if canImport(WatchConnectivity)
    public static var watchConnectivityManager: WatchConnectivityManager {
        WatchConnectivityManager.shared
    }
    #endif
    
    // MARK: - Live Activities
    #if canImport(ActivityKit)
    @MainActor
    public static var liveActivityManager: LiveActivityManager {
        LiveActivityManager.shared
    }
    #endif
    
    // MARK: - Theme Management
    @MainActor
    public static var themeManager: ThemeManager {
        ThemeManager.shared
    }
}