import SwiftUI
import HabitTrackerFeature

@main
struct HabitTrackerApp: App {
    var body: some Scene {
        WindowGroup {
            HabitTrackerFeature.morningRoutineView()
        }
    }
}
