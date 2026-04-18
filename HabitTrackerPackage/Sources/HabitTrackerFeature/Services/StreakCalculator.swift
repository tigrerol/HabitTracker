import Foundation

/// Pure, stateless calculator that derives weekly streak statistics for a routine
/// from a set of `RoutineSessionData` records. No SwiftData or UI dependencies.
public struct StreakCalculator: Sendable {

    /// Statistics for a single ISO week (Monday-first).
    public struct WeekStats: Sendable, Equatable {
        /// Monday 00:00 local time for this week.
        public let weekStart: Date
        /// Number of finished sessions for each weekday. Index 0 = Monday, 6 = Sunday.
        public let completionsPerDay: [Int]

        public init(weekStart: Date, completionsPerDay: [Int]) {
            precondition(completionsPerDay.count == 7, "completionsPerDay must have 7 entries")
            self.weekStart = weekStart
            self.completionsPerDay = completionsPerDay
        }

        /// Number of distinct days the routine was completed this week.
        public var completedDayCount: Int {
            completionsPerDay.filter { $0 > 0 }.count
        }

        /// Whether the weekly target was met.
        public func meetsTarget(_ target: Int) -> Bool {
            completedDayCount >= target
        }
    }

    /// Full computed streak data for a single routine, ready for the view.
    public struct RoutineStreakData: Sendable, Identifiable {
        public var id: UUID { template.id }
        public let template: RoutineTemplate
        /// The target that was used for evaluation (unwrapped).
        public let target: Int
        public let currentWeek: WeekStats
        /// Up to 4 entries, newest first (`−1w`, `−2w`, `−3w`, `−4w`).
        public let previousWeeks: [WeekStats]
        /// Consecutive met prior weeks that fall *beyond* `previousWeeks`.
        public let extendedStreakBeyond: Int
        /// Total consecutive prior weeks where target was met (excludes the current week).
        public let totalStreak: Int
    }

    /// Build 7 per-day session counts for the week starting at `weekStart`,
    /// counting only sessions whose `completedAt` falls inside that week.
    /// Index 0 = Monday (given a Monday-first `calendar`).
    private static func bucket(
        sessions: [RoutineSessionData],
        weekStart: Date,
        calendar: Calendar
    ) -> [Int] {
        guard let weekEnd = calendar.date(byAdding: .weekOfYear, value: 1, to: weekStart) else {
            return Array(repeating: 0, count: 7)
        }
        var counts = Array(repeating: 0, count: 7)
        for session in sessions {
            guard let completedAt = session.completedAt,
                  completedAt >= weekStart, completedAt < weekEnd else { continue }
            // Weekday: Monday-first calendar has firstWeekday = 2, so Monday's weekday == 2.
            // We want Monday → 0 … Sunday → 6.
            let weekday = calendar.component(.weekday, from: completedAt)
            let index = (weekday - calendar.firstWeekday + 7) % 7
            counts[index] += 1
        }
        return counts
    }

    /// Compute streak data for a routine. Returns `nil` when the routine does not
    /// track a weekly target.
    public static func compute(
        for template: RoutineTemplate,
        sessions: [RoutineSessionData],
        now: Date,
        calendar: Calendar
    ) -> RoutineStreakData? {
        guard let target = template.weeklyTarget else { return nil }

        let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now)!
        let currentWeekStart = weekInterval.start

        let currentWeek = WeekStats(
            weekStart: currentWeekStart,
            completionsPerDay: bucket(sessions: sessions, weekStart: currentWeekStart, calendar: calendar)
        )

        // Previous 4 weeks, newest first.
        var previousWeeks: [WeekStats] = []
        for offset in 1...4 {
            let start = calendar.date(byAdding: .weekOfYear, value: -offset, to: currentWeekStart)!
            previousWeeks.append(WeekStats(
                weekStart: start,
                completionsPerDay: bucket(sessions: sessions, weekStart: start, calendar: calendar)
            ))
        }

        // Total streak: walk backwards from -1w, count consecutive met weeks.
        var totalStreak = 0
        var offset = 1
        let hardCap = 520 // 10 years — avoid pathological loops.
        while offset <= hardCap {
            let start = calendar.date(byAdding: .weekOfYear, value: -offset, to: currentWeekStart)!
            let counts = bucket(sessions: sessions, weekStart: start, calendar: calendar)
            let week = WeekStats(weekStart: start, completionsPerDay: counts)
            if week.meetsTarget(target) {
                totalStreak += 1
                offset += 1
            } else {
                break
            }
        }

        let extendedStreakBeyond = max(0, totalStreak - previousWeeks.count)

        return RoutineStreakData(
            template: template,
            target: target,
            currentWeek: currentWeek,
            previousWeeks: previousWeeks,
            extendedStreakBeyond: extendedStreakBeyond,
            totalStreak: totalStreak
        )
    }
}
