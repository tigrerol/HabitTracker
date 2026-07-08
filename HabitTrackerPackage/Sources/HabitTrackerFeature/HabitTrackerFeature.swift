import SwiftUI
import SwiftData
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

    /// The app-wide SwiftData container; inject via `.modelContainer(_:)`.
    @MainActor
    public static var sharedModelContainer: ModelContainer {
        DataModelConfiguration.sharedContainer
    }
    
    @MainActor
    public static func themeCustomizationView() -> some View {
        ThemeCustomizationView()
            .withDynamicTheme()
    }
    
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