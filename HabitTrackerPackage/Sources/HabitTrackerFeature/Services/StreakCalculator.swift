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

    /// Compute streak data for a routine. Returns `nil` when the routine does not
    /// track a weekly target.
    public static func compute(
        for template: RoutineTemplate,
        sessions: [RoutineSessionData],
        now: Date,
        calendar: Calendar
    ) -> RoutineStreakData? {
        // Implementation filled in by later tasks.
        return nil
    }
}
