import SwiftUI

// MARK: - Public API
public struct HabitTrackerFeature {
    @MainActor
    public static func morningRoutineView() -> some View {
        MorningRoutineView()
    }
    
    // MARK: - Watch Connectivity
    public static var watchConnectivityManager: WatchConnectivityManager {
        WatchConnectivityManager.shared
    }
}