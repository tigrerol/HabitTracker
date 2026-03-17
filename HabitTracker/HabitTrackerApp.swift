import SwiftUI
import SwiftData
import HabitTrackerFeature
#if canImport(ActivityKit)
import ActivityKit
#endif

@main
struct HabitTrackerApp: App {
    let modelContainer: ModelContainer

    init() {
        // Initialize WatchConnectivityManager on app startup
        _ = HabitTrackerFeature.watchConnectivityManager

        do {
            modelContainer = try DataModelConfiguration.createModelContainer()
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            HabitTrackerFeature.morningRoutineView()
                .modelContainer(modelContainer)
        }
    }
}
