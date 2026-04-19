import SwiftUI

/// Screen that lists every routine with a weekly target and shows its streak stats.
@MainActor
public struct StreaksView: View {
    @Environment(RoutineService.self) private var routineService
    @Environment(\.dismiss) private var dismiss
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
        .safeAreaInset(edge: .bottom) {
            PageDotsIndicator(
                currentIndex: 1,
                count: 2,
                labels: ["Habits", "Streaks, current page"]
            ) { index in
                if index == 0 {
                    dismiss()
                }
            }
            .padding(.bottom, 8)
        }
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
                currentWeekColumn
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
            if data.extendedStreakBeyond > 0 {
                Text("🔥 +\(data.extendedStreakBeyond) more")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.green)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.green.opacity(0.2))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(Color.green.opacity(0.4), lineWidth: 1)
                    )
                    .padding(.top, 4)
                    .accessibilityLabel("Plus \(data.extendedStreakBeyond) more consecutive weeks meeting target")
            }
        }
        .frame(width: 104)
    }

    private var currentWeekColumn: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("THIS WEEK · \(data.currentWeek.completedDayCount) / \(data.target)")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.secondaryText)
            HStack(spacing: 4) {
                ForEach(0..<7, id: \.self) { index in
                    daySquare(count: data.currentWeek.completionsPerDay[index], isFuture: isFutureDay(index))
                }
            }
            HStack(spacing: 4) {
                ForEach(["M", "T", "W", "T", "F", "S", "S"], id: \.self) { letter in
                    Text(letter)
                        .font(.system(size: 9))
                        .foregroundStyle(Theme.secondaryText)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func daySquare(count: Int, isFuture: Bool) -> some View {
        let fill: Color = {
            if count > 0 { return .green }
            if isFuture { return Color.gray.opacity(0.3) }
            return Color.gray.opacity(0.7)
        }()
        ZStack {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(fill)
                .aspectRatio(1, contentMode: .fit)
            if count >= 2 {
                Text("\(count)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.black)
            }
        }
    }

    private func isFutureDay(_ index: Int) -> Bool {
        // Today's weekday index 0…6 (Monday-first). A day is "future" if its index
        // is strictly greater than today's index for the current week.
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2
        cal.minimumDaysInFirstWeek = 4
        let weekday = cal.component(.weekday, from: Date())
        let todayIndex = (weekday - cal.firstWeekday + 7) % 7
        return index > todayIndex
    }
}
