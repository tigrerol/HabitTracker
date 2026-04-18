import SwiftUI

/// Screen that lists every routine with a weekly target and shows its streak stats.
@MainActor
public struct StreaksView: View {
    @Environment(RoutineService.self) private var routineService
    @State private var streaks: [StreakCalculator.RoutineStreakData] = []
    @State private var didLoadOnce = false

    public init() {}

    public var body: some View {
        Group {
            if streaks.isEmpty && didLoadOnce {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(streaks) { data in
                            RoutineStreakCard(data: data)
                        }
                    }
                    .padding()
                }
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Streaks")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: routineService.templates.count) {
            streaks = await routineService.computeStreaks(now: Date())
            didLoadOnce = true
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "flame")
                .font(.largeTitle)
                .foregroundStyle(Theme.secondaryText)
            Text("No streaks yet")
                .font(.headline)
            Text("Set a weekly target on a routine to start tracking streaks.")
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(32)
    }
}

struct RoutineStreakCard: View {
    let data: StreakCalculator.RoutineStreakData

    var body: some View {
        Text(data.template.name) // Filled in by later tasks.
    }
}
