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

    /// Creates N sessions per prior week at noon each Monday, going `weekCount`
    /// weeks back. Each prior week thus has exactly `daysPerWeek` unique
    /// completed days.
    static func priorWeekSessions(
        weekCount: Int,
        daysPerWeek: Int,
        relativeTo referenceNow: Date = now
    ) -> [RoutineSessionData] {
        var sessions: [RoutineSessionData] = []
        let cal = Calendar.mondayFirst
        let currentWeekStart = cal.dateInterval(of: .weekOfYear, for: referenceNow)!.start
        for w in 1...weekCount {
            let weekStart = cal.date(byAdding: .weekOfYear, value: -w, to: currentWeekStart)!
            for d in 0..<daysPerWeek {
                let day = cal.date(byAdding: .day, value: d, to: weekStart)!
                var comps = cal.dateComponents([.year, .month, .day], from: day)
                sessions.append(Self.session(onLocalDate: comps))
            }
        }
        return sessions
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

    @Test func totalStreakCountsConsecutiveMetWeeks() {
        // Target 3. Last 3 prior weeks have 3 days each (met). Week -4 has 1 day (missed).
        var sessions = Self.priorWeekSessions(weekCount: 3, daysPerWeek: 3)
        let cal = Calendar.mondayFirst
        let currentWeekStart = cal.dateInterval(of: .weekOfYear, for: Self.now)!.start
        let w4 = cal.date(byAdding: .weekOfYear, value: -4, to: currentWeekStart)!
        let w4Comps = cal.dateComponents([.year, .month, .day], from: w4)
        sessions.append(Self.session(onLocalDate: w4Comps))

        let template = RoutineTemplate(name: "Morning", weeklyTarget: 3)
        let data = try! #require(StreakCalculator.compute(
            for: template,
            sessions: sessions,
            now: Self.now,
            calendar: .mondayFirst
        ))
        #expect(data.totalStreak == 3)
        #expect(data.extendedStreakBeyond == 0)
    }

    @Test func extendedStreakBeyondVisibleWindow() {
        // 10 prior weeks all met. previousWeeks shows 4; extended = 6.
        let sessions = Self.priorWeekSessions(weekCount: 10, daysPerWeek: 3)
        let template = RoutineTemplate(name: "Morning", weeklyTarget: 3)
        let data = try! #require(StreakCalculator.compute(
            for: template,
            sessions: sessions,
            now: Self.now,
            calendar: .mondayFirst
        ))
        #expect(data.totalStreak == 10)
        #expect(data.extendedStreakBeyond == 6)
        for week in data.previousWeeks {
            #expect(week.meetsTarget(3))
        }
    }

    @Test func streakIsZeroWhenMostRecentPriorWeekMissed() {
        // Target 3. Week -1 has 1 day (missed). Older weeks with 3 days don't matter.
        var sessions: [RoutineSessionData] = []
        let cal = Calendar.mondayFirst
        let currentWeekStart = cal.dateInterval(of: .weekOfYear, for: Self.now)!.start
        let w1 = cal.date(byAdding: .weekOfYear, value: -1, to: currentWeekStart)!
        sessions.append(Self.session(
            onLocalDate: cal.dateComponents([.year, .month, .day], from: w1)
        ))
        for w in 2...5 {
            let ws = cal.date(byAdding: .weekOfYear, value: -w, to: currentWeekStart)!
            for d in 0..<3 {
                let day = cal.date(byAdding: .day, value: d, to: ws)!
                sessions.append(Self.session(
                    onLocalDate: cal.dateComponents([.year, .month, .day], from: day)
                ))
            }
        }
        let template = RoutineTemplate(name: "Morning", weeklyTarget: 3)
        let data = try! #require(StreakCalculator.compute(
            for: template,
            sessions: sessions,
            now: Self.now,
            calendar: .mondayFirst
        ))
        #expect(data.totalStreak == 0)
        #expect(data.extendedStreakBeyond == 0)
    }

    @Test func previousWeeksArePopulatedNewestFirst() {
        let template = RoutineTemplate(name: "Morning", weeklyTarget: 3)
        // Week -1 starts Mon 2026-04-06. Three sessions in that week.
        let w1Mon = DateComponents(year: 2026, month: 4, day: 6)
        let w1Wed = DateComponents(year: 2026, month: 4, day: 8)
        let w1Fri = DateComponents(year: 2026, month: 4, day: 10)
        // Week -3 starts Mon 2026-03-23. One session on Thursday.
        let w3Thu = DateComponents(year: 2026, month: 3, day: 26)
        let sessions = [
            Self.session(onLocalDate: w1Mon),
            Self.session(onLocalDate: w1Wed),
            Self.session(onLocalDate: w1Fri),
            Self.session(onLocalDate: w3Thu)
        ]
        let data = try! #require(StreakCalculator.compute(
            for: template,
            sessions: sessions,
            now: Self.now,
            calendar: .mondayFirst
        ))
        #expect(data.previousWeeks.count == 4)
        // Newest first: index 0 = -1w, index 3 = -4w.
        #expect(data.previousWeeks[0].completionsPerDay == [1, 0, 1, 0, 1, 0, 0])
        #expect(data.previousWeeks[0].completedDayCount == 3)
        #expect(data.previousWeeks[0].meetsTarget(3))
        #expect(data.previousWeeks[2].completionsPerDay == [0, 0, 0, 1, 0, 0, 0])
        #expect(data.previousWeeks[2].completedDayCount == 1)
        #expect(!data.previousWeeks[2].meetsTarget(3))
        // -2w and -4w should be all zeros.
        #expect(data.previousWeeks[1].completedDayCount == 0)
        #expect(data.previousWeeks[3].completedDayCount == 0)
    }

    @Test func weekBoundaryMondayFirst() {
        // Session at Sunday 2026-04-12 23:59 local belongs to week ending 2026-04-12
        // (which is -1w). A session at Monday 2026-04-13 00:01 local belongs to the
        // current week.
        var sundayLate = DateComponents(year: 2026, month: 4, day: 12, hour: 23, minute: 59)
        var mondayEarly = DateComponents(year: 2026, month: 4, day: 13, hour: 0, minute: 1)
        sundayLate.second = 0
        mondayEarly.second = 0
        let sunday = Calendar.mondayFirst.date(from: sundayLate)!
        let monday = Calendar.mondayFirst.date(from: mondayEarly)!

        let sessions = [
            RoutineSessionData(id: UUID(), startedAt: sunday, completedAt: sunday,
                               currentHabitIndex: 0, completions: [], modifications: []),
            RoutineSessionData(id: UUID(), startedAt: monday, completedAt: monday,
                               currentHabitIndex: 0, completions: [], modifications: [])
        ]
        let template = RoutineTemplate(name: "Morning", weeklyTarget: 1)
        let data = try! #require(StreakCalculator.compute(
            for: template,
            sessions: sessions,
            now: Self.now,
            calendar: .mondayFirst
        ))
        // Current week: Monday should be index 0 and have 1 completion.
        #expect(data.currentWeek.completionsPerDay[0] == 1)
        // -1w (previousWeeks[0]): Sunday should be index 6 and have 1 completion.
        #expect(data.previousWeeks[0].completionsPerDay[6] == 1)
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
