import SwiftUI
import SwiftData
import HabitTrackerFeature
#if canImport(ActivityKit)
import ActivityKit
#endif

@main
struct HabitTrackerApp: App {
    var body: some Scene {
        WindowGroup {
            HabitTrackerFeature.morningRoutineView()
                .modelContainer(HabitTrackerFeature.sharedModelContainer)
                .onOpenURL { url in
                    Router.shared.handle(url: url)
                }
        }
    }
}
