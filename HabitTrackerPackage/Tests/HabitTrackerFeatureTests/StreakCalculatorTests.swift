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

    /// Build a finished session whose `completedAt` falls on the given local date at noon.
    static func session(onLocalDate components: DateComponents, id: UUID = UUID()) -> RoutineSessionData {
        var c = components
        c.hour = 12; c.minute = 0; c.second = 0
        let date = Calendar.mondayFirst.date(from: c)!
        return RoutineSessionData(
            id: id,
            startedAt: date.addingTimeInterval(-600),
            completedAt: date,
            currentHabitIndex: 0,
            completions: [],
            modifications: []
        )
    }

    @Test func currentWeekBucketsSessionsByWeekday() {
        let template = RoutineTemplate(name: "Morning", weeklyTarget: 3)
        let monday    = DateComponents(year: 2026, month: 4, day: 13)
        let wednesday = DateComponents(year: 2026, month: 4, day: 15)
        let friday    = DateComponents(year: 2026, month: 4, day: 17)
        let sessions = [
            Self.session(onLocalDate: monday),
            Self.session(onLocalDate: wednesday),
            Self.session(onLocalDate: friday)
        ]
        let data = try! #require(StreakCalculator.compute(
            for: template,
            sessions: sessions,
            now: Self.now,
            calendar: .mondayFirst
        ))
        // Index 0 = Monday … 6 = Sunday
        #expect(data.currentWeek.completionsPerDay == [1, 0, 1, 0, 1, 0, 0])
        #expect(data.currentWeek.completedDayCount == 3)
        #expect(data.currentWeek.meetsTarget(3))
    }

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

    @Test func currentWeekIgnoresUnfinishedSessions() {
        let template = RoutineTemplate(name: "Morning", weeklyTarget: 1)
        let monday = DateComponents(year: 2026, month: 4, day: 13)
        var c = monday
        c.hour = 9; c.minute = 0
        let date = Calendar.mondayFirst.date(from: c)!
        let pending = RoutineSessionData(
            id: UUID(),
            startedAt: date,
            completedAt: nil,
            currentHabitIndex: 0,
            completions: [],
            modifications: []
        )
        let data = try! #require(StreakCalculator.compute(
            for: template,
            sessions: [pending],
            now: Self.now,
            calendar: .mondayFirst
        ))
        #expect(data.currentWeek.completionsPerDay.allSatisfy { $0 == 0 })
    }

    @Test func multipleSessionsSameDayIncrementCountButCountDayOnce() {
        // completedDayCount treats a day with 2 sessions as 1 met day.
        let template = RoutineTemplate(name: "Morning", weeklyTarget: 1)
        let tuesday = DateComponents(year: 2026, month: 4, day: 14)
        let sessions = [
            Self.session(onLocalDate: tuesday),
            Self.session(onLocalDate: tuesday)
        ]
        let data = try! #require(StreakCalculator.compute(
            for: template,
            sessions: sessions,
            now: Self.now,
            calendar: .mondayFirst
        ))
        // Tuesday index = 1.
        #expect(data.currentWeek.completionsPerDay[1] == 2)
        #expect(data.currentWeek.completedDayCount == 1)
        #expect(data.currentWeek.meetsTarget(1))
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
