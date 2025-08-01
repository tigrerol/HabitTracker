import SwiftUI
import HabitTrackerFeature
#if canImport(ActivityKit)
import ActivityKit
#endif

@main
struct HabitTrackerApp: App {
    init() {
        // Initialize WatchConnectivityManager on app startup
        _ = HabitTrackerFeature.watchConnectivityManager
    }
    
    var body: some Scene {
        WindowGroup {
            HabitTrackerFeature.morningRoutineView()
        }
    }
}
