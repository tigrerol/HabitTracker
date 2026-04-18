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
