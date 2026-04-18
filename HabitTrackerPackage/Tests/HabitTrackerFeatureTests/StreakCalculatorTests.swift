import Testing
import Foundation
@testable import HabitTrackerFeature

@Suite("StreakCalculator")
struct StreakCalculatorTests {

    /// Reference "now" used in every test: Wednesday 2026-04-15 10:00 local.
    /// Week-of-year starts Mon 2026-04-13, contains 2026-04-13…04-19.
    static let now: Date = {
        var c = DateComponents()
        c.year = 2026; c.month = 4; c.day = 15
        c.hour = 10; c.minute = 0; c.second = 0
        return Calendar.mondayFirst.date(from: c)!
    }()

    @Test func returnsNilWhenTargetIsNil() {
        let template = RoutineTemplate(name: "Morning", weeklyTarget: nil)
        let result = StreakCalculator.compute(
            for: template,
            sessions: [],
            now: Self.now,
            calendar: .mondayFirst
        )
        #expect(result == nil)
    }

    @Test func emptyHistoryProducesZeroValues() {
        let template = RoutineTemplate(name: "Morning", weeklyTarget: 3)
        let result = StreakCalculator.compute(
            for: template,
            sessions: [],
            now: Self.now,
            calendar: .mondayFirst
        )
        let data = try! #require(result)
        #expect(data.target == 3)
        #expect(data.currentWeek.completionsPerDay == [0, 0, 0, 0, 0, 0, 0])
        #expect(data.previousWeeks.count == 4)
        for week in data.previousWeeks {
            #expect(week.completionsPerDay == [0, 0, 0, 0, 0, 0, 0])
        }
        #expect(data.totalStreak == 0)
        #expect(data.extendedStreakBeyond == 0)
    }
}

// MARK: - Test helpers

extension Calendar {
    /// Monday-first Gregorian calendar used for deterministic tests.
    static var mondayFirst: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2           // Monday
        cal.minimumDaysInFirstWeek = 4 // ISO
        cal.timeZone = TimeZone(identifier: "Europe/Vienna")!
        return cal
    }
}
