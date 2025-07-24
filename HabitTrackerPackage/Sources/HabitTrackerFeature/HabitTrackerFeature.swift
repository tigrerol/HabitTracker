import SwiftUI

// MARK: - Public API
public struct HabitTrackerFeature {
    @MainActor
    public static func morningRoutineView() -> some View {
        MorningRoutineView()
    }
}