# Weekly Streaks Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a weekly completion target to routines and a new Streaks screen that shows current-week progress + the previous 4 weeks' pass/fail status per routine.

**Architecture:** One optional `weeklyTarget: Int?` field on `RoutineTemplate` (and its SwiftData counterpart). A pure, `Sendable` `StreakCalculator` derives stats from existing `PersistedRoutineSession` rows on demand. New `StreaksView` + `RoutineStreakCard` render the approved layout. Entry is via a toolbar icon + swipe-left gesture on `SmartTemplateSelectionView`. Weekly target is set inside `RoutineBuilderView`.

**Tech Stack:** Swift 6.1, SwiftUI, SwiftData (existing), Swift Testing (existing). iOS 18+.

**Spec:** `docs/superpowers/specs/2026-04-18-weekly-streaks-design.md`.

**Key conventions picked up from the codebase:**
- All feature code lives in `HabitTrackerPackage/Sources/HabitTrackerFeature/`.
- Tests live in `HabitTrackerPackage/Tests/HabitTrackerFeatureTests/`, use Swift Testing (`import Testing`, `@Test`, `#expect`).
- `@MainActor` on all UI/service code. `Theme.background`, `Theme.cardBackground`, etc., come from `Utils/ColorExtensions.swift`.
- Do **not** add UI tests — the project's `CLAUDE.local.md` forbids automated UI testing.
- `swift_package_test` via XcodeBuildMCP is the canonical way to run the test suite; `swift test --package-path HabitTrackerPackage` also works from a terminal.

---

## Task 1: Add `weeklyTarget` to `RoutineTemplate` domain model

**Files:**
- Modify: `HabitTrackerPackage/Sources/HabitTrackerFeature/Models/RoutineTemplate.swift`
- Test: `HabitTrackerPackage/Tests/HabitTrackerFeatureTests/RoutineTemplateWeeklyTargetTests.swift` (new)

- [ ] **Step 1: Write the failing test**

Create `HabitTrackerPackage/Tests/HabitTrackerFeatureTests/RoutineTemplateWeeklyTargetTests.swift`:

```swift
import Testing
import Foundation
@testable import HabitTrackerFeature

@Suite("RoutineTemplate weeklyTarget")
struct RoutineTemplateWeeklyTargetTests {

    @Test func defaultIsNil() {
        let template = RoutineTemplate(name: "Morning")
        #expect(template.weeklyTarget == nil)
    }

    @Test func initStoresTarget() {
        let template = RoutineTemplate(name: "Morning", weeklyTarget: 5)
        #expect(template.weeklyTarget == 5)
    }

    @Test func codableRoundTripPreservesTarget() throws {
        let template = RoutineTemplate(name: "Morning", weeklyTarget: 3)
        let data = try JSONEncoder().encode(template)
        let decoded = try JSONDecoder().decode(RoutineTemplate.self, from: data)
        #expect(decoded.weeklyTarget == 3)
    }

    @Test func codableRoundTripHandlesNilTarget() throws {
        let template = RoutineTemplate(name: "Morning")
        let data = try JSONEncoder().encode(template)
        let decoded = try JSONDecoder().decode(RoutineTemplate.self, from: data)
        #expect(decoded.weeklyTarget == nil)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --package-path HabitTrackerPackage --filter RoutineTemplateWeeklyTargetTests`

Expected: FAIL with "value of type 'RoutineTemplate' has no member 'weeklyTarget'" or similar compile error.

- [ ] **Step 3: Add the property and init param**

In `Models/RoutineTemplate.swift`, add the stored property below `contextRule`:

```swift
public struct RoutineTemplate: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var description: String?
    public var habits: [Habit]
    public var color: String
    public var isDefault: Bool
    public let createdAt: Date
    public var lastUsedAt: Date?
    public var contextRule: RoutineContextRule?
    public var weeklyTarget: Int?

    public init(
        id: UUID = UUID(),
        name: String,
        description: String? = nil,
        habits: [Habit] = [],
        color: String = "#34C759",
        isDefault: Bool = false,
        createdAt: Date = Date(),
        lastUsedAt: Date? = nil,
        contextRule: RoutineContextRule? = nil,
        weeklyTarget: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.habits = habits.sorted { $0.order < $1.order }
        self.color = color
        self.isDefault = isDefault
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
        self.contextRule = contextRule
        self.weeklyTarget = weeklyTarget
    }
}
```

- [ ] **Step 4: Run tests**

Run: `swift test --package-path HabitTrackerPackage --filter RoutineTemplateWeeklyTargetTests`

Expected: 4 tests PASS.

- [ ] **Step 5: Run full suite to check for compile regressions from the new init param**

Run: `swift test --package-path HabitTrackerPackage`

Expected: all tests pass. (The new init param is defaulted, so call sites shouldn't break.)

- [ ] **Step 6: Commit**

```bash
git add HabitTrackerPackage/Sources/HabitTrackerFeature/Models/RoutineTemplate.swift \
        HabitTrackerPackage/Tests/HabitTrackerFeatureTests/RoutineTemplateWeeklyTargetTests.swift
git commit -m "feat: add weeklyTarget to RoutineTemplate"
```

---

## Task 2: Add `weeklyTarget` to `PersistedRoutineTemplate`

**Files:**
- Modify: `HabitTrackerPackage/Sources/HabitTrackerFeature/Models/SwiftDataModels.swift`
- Test: `HabitTrackerPackage/Tests/HabitTrackerFeatureTests/PersistedRoutineTemplateWeeklyTargetTests.swift` (new)

- [ ] **Step 1: Write the failing test**

Create `HabitTrackerPackage/Tests/HabitTrackerFeatureTests/PersistedRoutineTemplateWeeklyTargetTests.swift`:

```swift
import Testing
import Foundation
import SwiftData
@testable import HabitTrackerFeature

@Suite("PersistedRoutineTemplate weeklyTarget round-trip")
struct PersistedRoutineTemplateWeeklyTargetTests {

    @MainActor
    @Test func domainToPersistedToDomainPreservesTarget() throws {
        let container = try DataModelConfiguration.createTestModelContainer()
        let context = ModelContext(container)

        let original = RoutineTemplate(name: "Morning", weeklyTarget: 5)
        let persisted = PersistedRoutineTemplate(from: original)
        context.insert(persisted)
        try context.save()

        let restored = persisted.toDomainModel()
        #expect(restored.weeklyTarget == 5)
    }

    @MainActor
    @Test func updatePropagatesTargetChange() throws {
        let container = try DataModelConfiguration.createTestModelContainer()
        let context = ModelContext(container)

        var template = RoutineTemplate(name: "Morning", weeklyTarget: 3)
        let persisted = PersistedRoutineTemplate(from: template)
        context.insert(persisted)
        try context.save()

        template.weeklyTarget = 7
        persisted.update(from: template)

        #expect(persisted.toDomainModel().weeklyTarget == 7)
    }

    @MainActor
    @Test func nilTargetPersists() throws {
        let container = try DataModelConfiguration.createTestModelContainer()
        let context = ModelContext(container)

        let original = RoutineTemplate(name: "Morning")
        let persisted = PersistedRoutineTemplate(from: original)
        context.insert(persisted)
        try context.save()

        #expect(persisted.toDomainModel().weeklyTarget == nil)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --package-path HabitTrackerPackage --filter PersistedRoutineTemplateWeeklyTargetTests`

Expected: FAIL — compile error or values not preserved (since `PersistedRoutineTemplate` has no `weeklyTarget` yet and `toDomainModel()` doesn't pass it through).

- [ ] **Step 3: Add `weeklyTarget` to `PersistedRoutineTemplate`**

In `Models/SwiftDataModels.swift`, modify `PersistedRoutineTemplate`:

Add stored property (after `contextRuleData`):

```swift
public var weeklyTarget: Int?
```

In `init(from template: RoutineTemplate)`, before the closing brace, add:

```swift
self.weeklyTarget = template.weeklyTarget
```

In `toDomainModel()`, change the `return RoutineTemplate(...)` to include `weeklyTarget`:

```swift
return RoutineTemplate(
    id: id,
    name: name,
    description: templateDescription,
    habits: domainHabits,
    color: colorHex,
    isDefault: isDefault,
    createdAt: createdAt,
    lastUsedAt: lastUsedAt,
    contextRule: contextRule,
    weeklyTarget: weeklyTarget
)
```

In `update(from template: RoutineTemplate)`, add near the other assignments:

```swift
self.weeklyTarget = template.weeklyTarget
```

- [ ] **Step 4: Run tests**

Run: `swift test --package-path HabitTrackerPackage --filter PersistedRoutineTemplateWeeklyTargetTests`

Expected: 3 tests PASS.

- [ ] **Step 5: Run full suite**

Run: `swift test --package-path HabitTrackerPackage`

Expected: all tests pass. SwiftData auto-migrates a new optional property so existing data stays intact.

- [ ] **Step 6: Commit**

```bash
git add HabitTrackerPackage/Sources/HabitTrackerFeature/Models/SwiftDataModels.swift \
        HabitTrackerPackage/Tests/HabitTrackerFeatureTests/PersistedRoutineTemplateWeeklyTargetTests.swift
git commit -m "feat: persist weeklyTarget on PersistedRoutineTemplate"
```

---

## Task 3: Create `StreakCalculator` skeleton

**Files:**
- Create: `HabitTrackerPackage/Sources/HabitTrackerFeature/Services/StreakCalculator.swift`

- [ ] **Step 1: Create the file with types only (no logic yet)**

```swift
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
```

- [ ] **Step 2: Verify it compiles**

Run: `swift build --package-path HabitTrackerPackage`

Expected: build succeeds (no call sites yet).

- [ ] **Step 3: Commit**

```bash
git add HabitTrackerPackage/Sources/HabitTrackerFeature/Services/StreakCalculator.swift
git commit -m "feat: scaffold StreakCalculator types"
```

---

## Task 4: `compute` returns `nil` when target is not set

**Files:**
- Create: `HabitTrackerPackage/Tests/HabitTrackerFeatureTests/StreakCalculatorTests.swift`
- Modify: `HabitTrackerPackage/Sources/HabitTrackerFeature/Services/StreakCalculator.swift`

- [ ] **Step 1: Write the failing test**

Create `HabitTrackerPackage/Tests/HabitTrackerFeatureTests/StreakCalculatorTests.swift`:

```swift
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
```

- [ ] **Step 2: Run test to verify it passes already**

Run: `swift test --package-path HabitTrackerPackage --filter StreakCalculatorTests/returnsNilWhenTargetIsNil`

Expected: PASS — our scaffold already returns `nil` unconditionally.

- [ ] **Step 3: Commit the test and helper**

```bash
git add HabitTrackerPackage/Tests/HabitTrackerFeatureTests/StreakCalculatorTests.swift
git commit -m "test: add StreakCalculator nil-target case"
```

---

## Task 5: Empty history produces zero-valued current + 4 prior weeks

**Files:**
- Modify: `HabitTrackerPackage/Tests/HabitTrackerFeatureTests/StreakCalculatorTests.swift`
- Modify: `HabitTrackerPackage/Sources/HabitTrackerFeature/Services/StreakCalculator.swift`

- [ ] **Step 1: Add the failing test**

Append to `StreakCalculatorTests`:

```swift
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --package-path HabitTrackerPackage --filter StreakCalculatorTests/emptyHistoryProducesZeroValues`

Expected: FAIL — `result` is nil because scaffold returns nil.

- [ ] **Step 3: Implement the happy-path skeleton of `compute`**

Replace the body of `compute` in `StreakCalculator.swift`:

```swift
public static func compute(
    for template: RoutineTemplate,
    sessions: [RoutineSessionData],
    now: Date,
    calendar: Calendar
) -> RoutineStreakData? {
    guard let target = template.weeklyTarget else { return nil }

    let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now)!
    let currentWeekStart = weekInterval.start

    // Build current week with zeros; later tasks will populate it.
    let currentWeek = WeekStats(
        weekStart: currentWeekStart,
        completionsPerDay: Array(repeating: 0, count: 7)
    )

    // Previous 4 weeks, newest first.
    var previousWeeks: [WeekStats] = []
    for offset in 1...4 {
        let start = calendar.date(byAdding: .weekOfYear, value: -offset, to: currentWeekStart)!
        previousWeeks.append(WeekStats(
            weekStart: start,
            completionsPerDay: Array(repeating: 0, count: 7)
        ))
    }

    return RoutineStreakData(
        template: template,
        target: target,
        currentWeek: currentWeek,
        previousWeeks: previousWeeks,
        extendedStreakBeyond: 0,
        totalStreak: 0
    )
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --package-path HabitTrackerPackage --filter StreakCalculatorTests/emptyHistoryProducesZeroValues`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add HabitTrackerPackage/Sources/HabitTrackerFeature/Services/StreakCalculator.swift \
        HabitTrackerPackage/Tests/HabitTrackerFeatureTests/StreakCalculatorTests.swift
git commit -m "feat: StreakCalculator empty-history baseline"
```

---

## Task 6: Current week buckets finished sessions by weekday

**Files:**
- Modify: `HabitTrackerPackage/Tests/HabitTrackerFeatureTests/StreakCalculatorTests.swift`
- Modify: `HabitTrackerPackage/Sources/HabitTrackerFeature/Services/StreakCalculator.swift`

- [ ] **Step 1: Add a helper and the failing test**

Inside `StreakCalculatorTests` add a session-factory helper and a test. Place the helper below the existing `now` constant:

```swift
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --package-path HabitTrackerPackage --filter StreakCalculatorTests/currentWeekBucketsSessionsByWeekday`

Expected: FAIL — `completionsPerDay` is still all zeros.

- [ ] **Step 3: Implement bucketing**

In `StreakCalculator.swift`, add a private helper and update `compute`:

Add above `public static func compute`:

```swift
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
```

In `compute`, replace the line that builds `currentWeek` with:

```swift
let currentWeek = WeekStats(
    weekStart: currentWeekStart,
    completionsPerDay: bucket(sessions: sessions, weekStart: currentWeekStart, calendar: calendar)
)
```

- [ ] **Step 4: Run the test**

Run: `swift test --package-path HabitTrackerPackage --filter StreakCalculatorTests/currentWeekBucketsSessionsByWeekday`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add HabitTrackerPackage/Sources/HabitTrackerFeature/Services/StreakCalculator.swift \
        HabitTrackerPackage/Tests/HabitTrackerFeatureTests/StreakCalculatorTests.swift
git commit -m "feat: StreakCalculator current-week bucketing"
```

---

## Task 7: Unfinished sessions and duplicate-day handling

**Files:**
- Modify: `HabitTrackerPackage/Tests/HabitTrackerFeatureTests/StreakCalculatorTests.swift`

- [ ] **Step 1: Add the tests**

Append to `StreakCalculatorTests`:

```swift
@Test func currentWeekIgnoresUnfinishedSessions() {
    let template = RoutineTemplate(name: "Morning", weeklyTarget: 1)
    let monday = DateComponents(year: 2026, month: 4, day: 13)
    var c = monday
    c.hour = 9; c.minute = 0
    let date = Calendar.mondayFirst.date(from: c)!
    let pending = RoutineSessionData(
        id: UUID(),
        startedAt: date,
        completedAt: nil,           // <- unfinished
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
    // Q4: completedDayCount treats a day with 2 sessions as 1 met day.
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
```

- [ ] **Step 2: Run tests**

Run: `swift test --package-path HabitTrackerPackage --filter StreakCalculatorTests`

Expected: both new tests PASS. (The bucketing code from Task 6 already drops `nil` completedAt and accumulates counts; `completedDayCount` already filters by `>0`.)

- [ ] **Step 3: Commit (test-only if nothing changed in source)**

```bash
git add HabitTrackerPackage/Tests/HabitTrackerFeatureTests/StreakCalculatorTests.swift
git commit -m "test: StreakCalculator ignores pending sessions, dedupes same-day"
```

---

## Task 8: Populate previous 4 weeks

**Files:**
- Modify: `HabitTrackerPackage/Tests/HabitTrackerFeatureTests/StreakCalculatorTests.swift`
- Modify: `HabitTrackerPackage/Sources/HabitTrackerFeature/Services/StreakCalculator.swift`

- [ ] **Step 1: Add the failing test**

```swift
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --package-path HabitTrackerPackage --filter StreakCalculatorTests/previousWeeksArePopulatedNewestFirst`

Expected: FAIL — previous weeks are still all zeros.

- [ ] **Step 3: Populate `previousWeeks` with real buckets**

In `StreakCalculator.compute`, replace the `previousWeeks` loop with:

```swift
var previousWeeks: [WeekStats] = []
for offset in 1...4 {
    let start = calendar.date(byAdding: .weekOfYear, value: -offset, to: currentWeekStart)!
    previousWeeks.append(WeekStats(
        weekStart: start,
        completionsPerDay: bucket(sessions: sessions, weekStart: start, calendar: calendar)
    ))
}
```

- [ ] **Step 4: Run test to verify pass**

Run: `swift test --package-path HabitTrackerPackage --filter StreakCalculatorTests/previousWeeksArePopulatedNewestFirst`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add HabitTrackerPackage/Sources/HabitTrackerFeature/Services/StreakCalculator.swift \
        HabitTrackerPackage/Tests/HabitTrackerFeatureTests/StreakCalculatorTests.swift
git commit -m "feat: StreakCalculator populates previous 4 weeks"
```

---

## Task 9: `totalStreak` and `extendedStreakBeyond`

**Files:**
- Modify: `HabitTrackerPackage/Tests/HabitTrackerFeatureTests/StreakCalculatorTests.swift`
- Modify: `HabitTrackerPackage/Sources/HabitTrackerFeature/Services/StreakCalculator.swift`

- [ ] **Step 1: Add failing tests**

```swift
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --package-path HabitTrackerPackage --filter StreakCalculatorTests`

Expected: the 3 new tests FAIL (totalStreak is hardcoded to 0).

- [ ] **Step 3: Implement streak computation**

Replace the placeholder `return RoutineStreakData(...)` at the end of `compute` with:

```swift
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
```

*Performance note:* The hard cap of 520 weeks prevents runaway loops. For typical users the loop exits within a handful of iterations at the first missed week.

- [ ] **Step 4: Run tests**

Run: `swift test --package-path HabitTrackerPackage --filter StreakCalculatorTests`

Expected: all tests PASS.

- [ ] **Step 5: Commit**

```bash
git add HabitTrackerPackage/Sources/HabitTrackerFeature/Services/StreakCalculator.swift \
        HabitTrackerPackage/Tests/HabitTrackerFeatureTests/StreakCalculatorTests.swift
git commit -m "feat: StreakCalculator totalStreak + extendedStreakBeyond"
```

---

## Task 10: Monday-first week boundary correctness

**Files:**
- Modify: `HabitTrackerPackage/Tests/HabitTrackerFeatureTests/StreakCalculatorTests.swift`

- [ ] **Step 1: Add the test**

```swift
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
```

- [ ] **Step 2: Run test**

Run: `swift test --package-path HabitTrackerPackage --filter StreakCalculatorTests/weekBoundaryMondayFirst`

Expected: PASS. (Our implementation already uses `weekStart <= completedAt < weekEnd` via the bucket helper.)

- [ ] **Step 3: Commit**

```bash
git add HabitTrackerPackage/Tests/HabitTrackerFeatureTests/StreakCalculatorTests.swift
git commit -m "test: StreakCalculator Monday-first boundary"
```

---

## Task 11: DST transition does not skip a week

**Files:**
- Modify: `HabitTrackerPackage/Tests/HabitTrackerFeatureTests/StreakCalculatorTests.swift`

- [ ] **Step 1: Add the test**

```swift
@Test func dstTransitionDoesNotSkipWeek() {
    // Europe/Vienna: DST starts on Sunday 2026-03-29 (Sun 02:00 → 03:00 local).
    // "Now" = Wednesday 2026-04-01 10:00 local.
    // Target 1. A session every Monday for -1w, -2w, -3w straddling the DST change.
    var nowComps = DateComponents(year: 2026, month: 4, day: 1, hour: 10, minute: 0, second: 0)
    let nowApril = Calendar.mondayFirst.date(from: nowComps)!

    let cal = Calendar.mondayFirst
    let currentWeekStart = cal.dateInterval(of: .weekOfYear, for: nowApril)!.start
    var sessions: [RoutineSessionData] = []
    for w in 1...3 {
        let weekStart = cal.date(byAdding: .weekOfYear, value: -w, to: currentWeekStart)!
        sessions.append(Self.session(
            onLocalDate: cal.dateComponents([.year, .month, .day], from: weekStart)
        ))
    }

    let template = RoutineTemplate(name: "Morning", weeklyTarget: 1)
    let data = try! #require(StreakCalculator.compute(
        for: template,
        sessions: sessions,
        now: nowApril,
        calendar: .mondayFirst
    ))
    #expect(data.totalStreak == 3)
    #expect(data.previousWeeks[0].meetsTarget(1))
    #expect(data.previousWeeks[1].meetsTarget(1))
    #expect(data.previousWeeks[2].meetsTarget(1))
}
```

- [ ] **Step 2: Run test**

Run: `swift test --package-path HabitTrackerPackage --filter StreakCalculatorTests/dstTransitionDoesNotSkipWeek`

Expected: PASS. (`Calendar.date(byAdding: .weekOfYear, ...)` is DST-safe.)

- [ ] **Step 3: Commit**

```bash
git add HabitTrackerPackage/Tests/HabitTrackerFeatureTests/StreakCalculatorTests.swift
git commit -m "test: StreakCalculator DST-safe week math"
```

---

## Task 12: Historical target changes re-evaluate prior weeks (Q7)

**Files:**
- Modify: `HabitTrackerPackage/Tests/HabitTrackerFeatureTests/StreakCalculatorTests.swift`

- [ ] **Step 1: Add the test**

```swift
@Test func historicalTargetChangesReEvaluate() {
    // Prior week -1 has 4 completed days. The routine's current target is 5.
    // Per Q7, the week should evaluate as MISSED even though it would have
    // been MET when the target was 3.
    let cal = Calendar.mondayFirst
    let currentWeekStart = cal.dateInterval(of: .weekOfYear, for: Self.now)!.start
    let w1 = cal.date(byAdding: .weekOfYear, value: -1, to: currentWeekStart)!
    var sessions: [RoutineSessionData] = []
    for d in 0..<4 {
        let day = cal.date(byAdding: .day, value: d, to: w1)!
        sessions.append(Self.session(
            onLocalDate: cal.dateComponents([.year, .month, .day], from: day)
        ))
    }

    let template = RoutineTemplate(name: "Morning", weeklyTarget: 5)
    let data = try! #require(StreakCalculator.compute(
        for: template,
        sessions: sessions,
        now: Self.now,
        calendar: .mondayFirst
    ))
    #expect(!data.previousWeeks[0].meetsTarget(5))
    #expect(data.totalStreak == 0)
}
```

- [ ] **Step 2: Run test**

Run: `swift test --package-path HabitTrackerPackage --filter StreakCalculatorTests/historicalTargetChangesReEvaluate`

Expected: PASS (the implementation always uses the template's *current* target — no snapshotting).

- [ ] **Step 3: Commit**

```bash
git add HabitTrackerPackage/Tests/HabitTrackerFeatureTests/StreakCalculatorTests.swift
git commit -m "test: StreakCalculator re-evaluates history against current target"
```

---

## Task 13: Extend `PersistenceServiceProtocol` with `loadRoutineSessions`

**Files:**
- Modify: `HabitTrackerPackage/Sources/HabitTrackerFeature/Services/PersistenceService.swift`
- Modify: `HabitTrackerPackage/Sources/HabitTrackerFeature/Services/SwiftDataPersistenceService.swift`

- [ ] **Step 1: Add the new protocol requirement**

In `PersistenceService.swift`, update the protocol:

```swift
public protocol PersistenceServiceProtocol: Sendable {
    func save<T: Codable & Sendable>(_ object: T, forKey key: String) async throws
    func load<T: Codable & Sendable>(_ type: T.Type, forKey key: String) async throws -> T?
    func delete(forKey key: String) async
    func exists(forKey key: String) async -> Bool

    /// Load finished and in-progress routine sessions for a given template.
    /// Implementations that don't persist sessions should return `[]`.
    func loadRoutineSessions(for templateId: UUID) async -> [RoutineSessionData]
}
```

- [ ] **Step 2: Implement `loadRoutineSessions` in `UserDefaultsPersistenceService`**

In `PersistenceService.swift`, add inside `UserDefaultsPersistenceService`:

```swift
public func loadRoutineSessions(for templateId: UUID) async -> [RoutineSessionData] {
    // UserDefaults persistence doesn't store sessions.
    []
}
```

- [ ] **Step 3: `SwiftDataPersistenceService` already has this method — confirm it conforms**

The method already exists at `SwiftDataPersistenceService.swift:167`. No code change needed; the protocol requirement picks up the existing implementation.

- [ ] **Step 4: Build and run tests**

Run: `swift test --package-path HabitTrackerPackage`

Expected: all tests pass. If any mock persistence service exists in tests (grep for `PersistenceServiceProtocol` conformances), add the stub `loadRoutineSessions` there too.

- [ ] **Step 5: Quick scan for other conformances**

Run: `grep -rn "PersistenceServiceProtocol" HabitTrackerPackage/Sources HabitTrackerPackage/Tests`

If any test fixture conforms, add a `func loadRoutineSessions(for: UUID) async -> [RoutineSessionData] { [] }` stub. Rerun tests.

- [ ] **Step 6: Commit**

```bash
git add HabitTrackerPackage/Sources/HabitTrackerFeature/Services/PersistenceService.swift \
        HabitTrackerPackage/Sources/HabitTrackerFeature/Services/SwiftDataPersistenceService.swift
# plus any fixture files touched in Step 5
git commit -m "feat: expose loadRoutineSessions on PersistenceServiceProtocol"
```

---

## Task 14: Add `RoutineService.computeStreaks(now:)`

**Files:**
- Modify: `HabitTrackerPackage/Sources/HabitTrackerFeature/Services/RoutineService.swift`
- Test: `HabitTrackerPackage/Tests/HabitTrackerFeatureTests/RoutineServiceStreaksTests.swift` (new)

- [ ] **Step 1: Write the failing test**

Create `HabitTrackerPackage/Tests/HabitTrackerFeatureTests/RoutineServiceStreaksTests.swift`:

```swift
import Testing
import Foundation
@testable import HabitTrackerFeature

/// Stub persistence service that returns a fixed session list per template id.
private actor StubPersistence: PersistenceServiceProtocol {
    var templates: [RoutineTemplate] = []
    var sessionsByTemplate: [UUID: [RoutineSessionData]] = [:]

    func save<T: Codable & Sendable>(_ object: T, forKey key: String) async throws {
        if key == PersistenceKeys.routineTemplates, let t = object as? [RoutineTemplate] {
            templates = t
        }
    }
    func load<T: Codable & Sendable>(_ type: T.Type, forKey key: String) async throws -> T? {
        if key == PersistenceKeys.routineTemplates { return templates as? T }
        return nil
    }
    func delete(forKey key: String) async {}
    func exists(forKey key: String) async -> Bool { true }

    func loadRoutineSessions(for templateId: UUID) async -> [RoutineSessionData] {
        sessionsByTemplate[templateId] ?? []
    }

    func setTemplates(_ t: [RoutineTemplate]) { templates = t }
    func setSessions(_ s: [RoutineSessionData], for id: UUID) { sessionsByTemplate[id] = s }
}

@Suite("RoutineService streak integration")
struct RoutineServiceStreaksTests {

    @MainActor
    @Test func computeStreaksReturnsOnlyRoutinesWithTarget() async throws {
        let stub = StubPersistence()
        let tracked = RoutineTemplate(name: "Tracked", habits: [Habit(name: "x", type: .task(subtasks: []))], weeklyTarget: 3)
        let untracked = RoutineTemplate(name: "Untracked", habits: [Habit(name: "y", type: .task(subtasks: []))])
        await stub.setTemplates([tracked, untracked])
        let service = RoutineService(persistenceService: stub)
        // Let the async loader finish.
        try await Task.sleep(for: .milliseconds(50))

        let streaks = await service.computeStreaks(now: Date())
        #expect(streaks.count == 1)
        #expect(streaks.first?.template.id == tracked.id)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --package-path HabitTrackerPackage --filter RoutineServiceStreaksTests`

Expected: FAIL — `computeStreaks` doesn't exist.

- [ ] **Step 3: Implement `computeStreaks`**

Add to `RoutineService.swift`, somewhere near the other public methods (e.g., right after `updateTemplate`):

```swift
/// Compute streak data for every routine that has a weekly target.
/// Results are sorted by `lastUsedAt` descending (nils last), matching
/// the order used elsewhere in the app.
@MainActor
public func computeStreaks(now: Date) async -> [StreakCalculator.RoutineStreakData] {
    var results: [StreakCalculator.RoutineStreakData] = []
    let sorted = templates.sorted { lhs, rhs in
        switch (lhs.lastUsedAt, rhs.lastUsedAt) {
        case let (l?, r?): return l > r
        case (_?, nil):    return true
        case (nil, _?):    return false
        case (nil, nil):   return lhs.createdAt > rhs.createdAt
        }
    }
    var calendar = Calendar(identifier: .gregorian)
    calendar.firstWeekday = 2
    calendar.minimumDaysInFirstWeek = 4

    for template in sorted where template.weeklyTarget != nil {
        let sessions = await persistenceService.loadRoutineSessions(for: template.id)
        if let data = StreakCalculator.compute(
            for: template,
            sessions: sessions,
            now: now,
            calendar: calendar
        ) {
            results.append(data)
        }
    }
    return results
}
```

- [ ] **Step 4: Run test**

Run: `swift test --package-path HabitTrackerPackage --filter RoutineServiceStreaksTests`

Expected: PASS.

- [ ] **Step 5: Run full suite**

Run: `swift test --package-path HabitTrackerPackage`

Expected: all tests pass.

- [ ] **Step 6: Commit**

```bash
git add HabitTrackerPackage/Sources/HabitTrackerFeature/Services/RoutineService.swift \
        HabitTrackerPackage/Tests/HabitTrackerFeatureTests/RoutineServiceStreaksTests.swift
git commit -m "feat: RoutineService.computeStreaks"
```

---

## Task 15: `StreaksView` scaffold with empty state

**Files:**
- Create: `HabitTrackerPackage/Sources/HabitTrackerFeature/Views/StreaksView.swift`

- [ ] **Step 1: Create the view**

```swift
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
```

- [ ] **Step 2: Also create `RoutineStreakCard` as a placeholder so the file compiles**

Append to the same file, below `StreaksView`:

```swift
struct RoutineStreakCard: View {
    let data: StreakCalculator.RoutineStreakData

    var body: some View {
        Text(data.template.name) // Filled in by later tasks.
    }
}
```

- [ ] **Step 3: Verify build**

Run: `swift build --package-path HabitTrackerPackage`

Expected: succeeds.

- [ ] **Step 4: Commit**

```bash
git add HabitTrackerPackage/Sources/HabitTrackerFeature/Views/StreaksView.swift
git commit -m "feat: StreaksView scaffold with empty state"
```

---

## Task 16: `RoutineStreakCard` — header and previous-week column

**Files:**
- Modify: `HabitTrackerPackage/Sources/HabitTrackerFeature/Views/StreaksView.swift`

- [ ] **Step 1: Replace `RoutineStreakCard` placeholder with the left-column + header implementation**

```swift
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
```

- [ ] **Step 2: Verify build**

Run: `swift build --package-path HabitTrackerPackage`

Expected: succeeds.

- [ ] **Step 3: Commit**

```bash
git add HabitTrackerPackage/Sources/HabitTrackerFeature/Views/StreaksView.swift
git commit -m "feat: RoutineStreakCard header + previous column"
```

---

## Task 17: `RoutineStreakCard` — current-week day squares

**Files:**
- Modify: `HabitTrackerPackage/Sources/HabitTrackerFeature/Views/StreaksView.swift`

- [ ] **Step 1: Add `currentWeekColumn` and wire it in**

Inside `RoutineStreakCard`, replace the `HStack(alignment: .top, spacing: 14)` body to include the current column:

```swift
HStack(alignment: .top, spacing: 14) {
    previousColumn
    currentWeekColumn
}
```

Add below `previousColumn`:

```swift
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
```

- [ ] **Step 2: Verify build**

Run: `swift build --package-path HabitTrackerPackage`

Expected: succeeds.

- [ ] **Step 3: Commit**

```bash
git add HabitTrackerPackage/Sources/HabitTrackerFeature/Views/StreaksView.swift
git commit -m "feat: RoutineStreakCard current-week row with day squares"
```

---

## Task 18: Extended-streak "+N more" pill

**Files:**
- Modify: `HabitTrackerPackage/Sources/HabitTrackerFeature/Views/StreaksView.swift`

- [ ] **Step 1: Append the pill to `previousColumn`**

Inside `previousColumn`, right after the `ForEach` closure and before the `}` that closes the `VStack`, add:

```swift
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
```

- [ ] **Step 2: Verify build**

Run: `swift build --package-path HabitTrackerPackage`

Expected: succeeds.

- [ ] **Step 3: Commit**

```bash
git add HabitTrackerPackage/Sources/HabitTrackerFeature/Views/StreaksView.swift
git commit -m "feat: RoutineStreakCard extended-streak pill"
```

---

## Task 19: Entry point — toolbar icon + swipe-left gesture

**Files:**
- Modify: `HabitTrackerPackage/Sources/HabitTrackerFeature/Views/SmartTemplateSelectionView.swift`

- [ ] **Step 1: Add state and gesture handling**

Add near the other `@State` declarations (around line 13):

```swift
@State private var showingStreaks = false
```

- [ ] **Step 2: Add a toolbar button**

In `.toolbar { … }` (around line 44–58), add a new `ToolbarItem` to `.navigationBarTrailing`, placed **before** the existing `.confirmationAction` plus button so the flame renders to its left:

```swift
ToolbarItem(placement: .navigationBarTrailing) {
    Button {
        showingStreaks = true
    } label: {
        Image(systemName: "flame")
            .fontWeight(.semibold)
            .foregroundStyle(themeManager.currentAccentColor)
    }
    .accessibilityLabel("Streaks")
}
```

**Why trailing:** the existing `.cancellationAction` (SettingsButton) already owns the leading slot. Adding another leading item would visually collide. Keep the flame on the right, left of the `+`.

- [ ] **Step 3: Wire the navigation destination**

Immediately after the closing brace of `.toolbar { ... }` (and before `.safeAreaInset`), add:

```swift
.navigationDestination(isPresented: $showingStreaks) {
    StreaksView()
        .environment(routineService)
}
```

- [ ] **Step 4: Add the swipe-left gesture**

On the outer `VStack(spacing: 24) { ... }` body (inside `NavigationStack`), add after `.background(Theme.background.ignoresSafeArea())`:

```swift
.contentShape(Rectangle())
.gesture(
    DragGesture(minimumDistance: 20)
        .onEnded { value in
            if value.translation.width < -80 && abs(value.translation.height) < 60 {
                showingStreaks = true
            }
        }
)
```

- [ ] **Step 5: Manual verification checklist (you run this, then paste any crashes/glitches back to the user)**

Build + run the app on an iPhone 16 simulator. Verify:
1. Flame icon appears in the nav bar on the routine selection screen.
2. Tapping it pushes `StreaksView`.
3. Swiping left anywhere in the main content area (but not on a template card tap target) pushes `StreaksView`.
4. Back swipe / back button returns to the selection screen.
5. No gesture conflicts with existing template taps.

Expected build: succeeds. Runtime: smooth nav.

- [ ] **Step 6: Commit**

```bash
git add HabitTrackerPackage/Sources/HabitTrackerFeature/Views/SmartTemplateSelectionView.swift
git commit -m "feat: streaks entry point — toolbar icon + swipe left"
```

---

## Task 20: Weekly-target controls in `RoutineBuilderView`

**Files:**
- Modify: `HabitTrackerPackage/Sources/HabitTrackerFeature/Views/RoutineBuilderView.swift`

- [ ] **Step 1: Add state for the target**

Near the other `@State` declarations at the top of `RoutineBuilderView` (around line 9–34), add:

```swift
@State private var weeklyTarget: Int? = nil
```

- [ ] **Step 2: Seed it from `editingTemplate`**

In the `.onAppear { ... }` block (around line 76–), where the other template fields are initialized, add right after `templateColor = template.color`:

```swift
weeklyTarget = template.weeklyTarget
```

- [ ] **Step 3: Add the "Streak tracking" UI to the naming step**

The naming step is rendered by `namingStepView`. Open `RoutineBuilderView.swift` and find that computed view. Add a new section at the end of its body (after existing fields, before the primary action button). Match the existing form-section styling used elsewhere in the file.

Use this exact code block — insert it as a new `VStack(alignment: .leading, spacing: 8)` immediately before the "Continue" / primary button:

```swift
VStack(alignment: .leading, spacing: 8) {
    Text("Streak tracking")
        .font(.headline)
    Toggle("Track streak", isOn: Binding(
        get: { weeklyTarget != nil },
        set: { weeklyTarget = $0 ? (weeklyTarget ?? 3) : nil }
    ))
    if let target = weeklyTarget {
        Stepper(
            "Weekly target: \(target)× per week",
            value: Binding(
                get: { weeklyTarget ?? 3 },
                set: { weeklyTarget = $0 }
            ),
            in: 1...7
        )
    }
}
.padding(.vertical, 8)
```

If `namingStepView` is very large and hard to navigate, locate it with `grep -n "namingStepView" HabitTrackerPackage/Sources/HabitTrackerFeature/Views/RoutineBuilderView.swift` before editing.

- [ ] **Step 4: Persist the field in `saveTemplate()`**

In `saveTemplate()` (around line 1814–1854):

Replace the "update existing template" block:

```swift
if let existingTemplate = editingTemplate {
    var updatedTemplate = existingTemplate
    updatedTemplate.name = templateName
    updatedTemplate.habits = habits
    updatedTemplate.color = templateColor
    updatedTemplate.isDefault = false
    updatedTemplate.contextRule = finalContextRule
    updatedTemplate.weeklyTarget = weeklyTarget
    routineService.updateTemplate(updatedTemplate)
} else {
    let template = RoutineTemplate(
        name: templateName,
        habits: habits,
        color: templateColor,
        isDefault: false,
        contextRule: finalContextRule,
        weeklyTarget: weeklyTarget
    )
    routineService.addTemplate(template)
}
```

- [ ] **Step 5: Build and run tests**

Run: `swift test --package-path HabitTrackerPackage`

Expected: all tests pass.

- [ ] **Step 6: Manual verification (paste logs/screenshots back to the user if anything's off)**

1. Open an existing routine → naming step → "Streak tracking" section visible, toggle off.
2. Toggle on → stepper appears at 3.
3. Bump to 5, save → reopen — target remembered.
4. Create a new routine with target 3 → appears on Streaks screen with `3×/week`.
5. Create a new routine without a target → does **not** appear on Streaks screen.

- [ ] **Step 7: Commit**

```bash
git add HabitTrackerPackage/Sources/HabitTrackerFeature/Views/RoutineBuilderView.swift
git commit -m "feat: weekly target setting in RoutineBuilderView"
```

---

## Task 21: Final verification

**Files:** none (manual check).

- [ ] **Step 1: Full test suite**

Run: `swift test --package-path HabitTrackerPackage`

Expected: all tests pass.

- [ ] **Step 2: Build the app target via XcodeBuildMCP**

Run via Claude Code's XcodeBuildMCP:

```javascript
build_sim_name_ws({
    workspacePath: "/Users/rolandlechner/SWDevelopment/ios/HabitTracker/HabitTracker.xcworkspace",
    scheme: "HabitTracker",
    simulatorName: "iPhone 16",
    configuration: "Debug"
})
```

Expected: build succeeds.

- [ ] **Step 3: Manual end-to-end check (report any issues to the user; do not run UI tests)**

1. Launch the app, land on the routine-selection screen.
2. Flame toolbar icon → navigates to Streaks (empty state if no routines have a target).
3. Swipe left on the selection screen → same navigation.
4. Edit a routine → enable "Track streak" → set target → save.
5. Start and complete that routine twice on the same day → on the Streaks screen, that day's square is green with "2" in black.
6. Open Streaks on a day later in the week → past days show green/dark gray, future days show the translucent state.

- [ ] **Step 4: Commit any test-suite deltas discovered during verification**

If verification uncovered a bug, fix it with a normal TDD cycle (add a regression test first), commit, and rerun the suite.

---

## Notes for the implementer

- **SwiftUI `LazyHStack` vs. `HStack`:** With only 7 day squares, `HStack` is fine — no lazy wrapper needed.
- **Localization strings:** The existing codebase uses `.module` bundle localizations heavily. This feature's strings (`"Streaks"`, `"Streak tracking"`, `"Track streak"`, `"This week"`, etc.) should later be added to `Localizable.strings`, but that can be a follow-up — the initial PR ships with English literals to keep the diff small.
- **Accessibility:** Each day-square uses inferred labels from the surrounding row. If VoiceOver reads them clumsily, consider adding explicit `.accessibilityLabel` + `.accessibilityHidden(true)` on redundant decorative elements — revisit after manual VoiceOver pass.
- **CloudKit:** The SwiftData schema already lists `PersistedRoutineTemplate` for CloudKit. The new `weeklyTarget: Int?` field is a safe additive change — CloudKit tolerates optional new fields.
