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
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(data.template.name)
                    .font(.headline)
                Spacer()
                if data.totalStreak > 0 {
                    Text("🔥 \(data.totalStreak) week streak")
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                } else {
                    Text("\(data.target)× / week")
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            HStack(alignment: .top, spacing: 14) {
                previousColumn
                // Current-week column added in Task 17.
            }
        }
        .padding(14)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var previousColumn: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("PREVIOUS")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.secondaryText)
            ForEach(Array(data.previousWeeks.enumerated()), id: \.offset) { offset, week in
                HStack(spacing: 6) {
                    Text("−\(offset + 1)w")
                        .font(.system(size: 9))
                        .foregroundStyle(Theme.secondaryText)
                        .frame(width: 22, alignment: .leading)
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(week.meetsTarget(data.target) ? Color.green : Color.red)
                        .frame(height: 12)
                    Text("\(week.completedDayCount)/\(data.target)")
                        .font(.system(size: 9))
                        .foregroundStyle(Theme.secondaryText)
                        .frame(width: 22, alignment: .trailing)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(
                    "Week minus \(offset + 1), \(week.completedDayCount) of \(data.target) days completed, target \(week.meetsTarget(data.target) ? "met" : "missed")"
                )
            }
        }
        .frame(width: 104)
    }
}
