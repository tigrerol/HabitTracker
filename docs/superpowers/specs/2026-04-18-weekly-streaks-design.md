# Weekly Streaks — Design

Date: 2026-04-18

## Summary

Add a per-routine **weekly target** (`1…7`, optional) and a new **Streaks** screen reached from the routine-selection screen via swipe-left or a toolbar icon. The screen lists every routine that has a target and visualizes:

- **Current week**: seven day-squares (Mon→Sun), green if the routine was finished at least once that day, with a black count for days with multiple sessions.
- **Previous 4 weeks**: a stacked column of colored bars (newest on top), green if the weekly target was met, red otherwise, with a `N/target` ratio label.
- **Extended streak**: if the met-target streak runs past the 4 displayed weeks, show a `🔥 +N more` pill.
- **Total streak**: `🔥 N week streak` badge in the card header (consecutive prior weeks where target was met, excluding the current week).

## Decisions (from brainstorming)

| # | Question | Decision |
|---|----------|----------|
| Q1 | What counts as "completed" on a day? | **B** — A finished session (`PersistedRoutineSession.completedAt != nil`). |
| Q2 | Week start | **A** — Monday (ISO 8601). Use `Calendar.current` with `firstWeekday = 2` explicitly to lock behavior. |
| Q3 | Target required? | **B** — Optional per routine. Routines with no target don't appear on the streaks screen. |
| Q4 | Multiple same-day completions | **A** — Count the *day* as met (1 day). Display the session count as black digit on the green square for visibility. |
| Q5 | Entry point | **B** — Toolbar icon **and** swipe-left gesture, both from `SmartTemplateSelectionView`. |
| Q6 | Target setting location | **A** — Routine Builder, as one optional field. |
| Q7 | Historical target changes | **A** — Simple: prior weeks re-evaluate against the *current* target. No per-week snapshotting. |
| Arch | Storage vs. compute | **A** — Compute on-the-fly from existing sessions; one new field on `RoutineTemplate`. No new tables. |

## Scope

**In scope:**

- Add `weeklyTarget: Int?` to the `RoutineTemplate` domain model and `PersistedRoutineTemplate` SwiftData model.
- Add a "Track streak" toggle + "Weekly target" stepper (1…7) in `RoutineBuilderView`.
- Implement `StreakCalculator` (pure `Sendable` struct) that derives current-week and prior-4-week stats plus total streak / extended streak from finished sessions.
- Implement `StreaksView` matching the approved layout (`layout-v3.html`).
- Implement `RoutineStreakCard` subview.
- Add swipe-left gesture + toolbar chart icon to `SmartTemplateSelectionView` that pushes `StreaksView` onto the existing `NavigationStack`.
- Swift Testing unit tests for `StreakCalculator`.

**Out of scope (explicitly deferred):**

- Per-day-type targets (e.g., "weekdays only" via existing `DayCategoryManager`). Future work.
- Per-week historical target snapshotting (Q7 option B).
- Streak notifications / reminders.
- Streak achievements / badges beyond the 🔥 counter.
- Sharing, export, Apple Health integration.
- Widget / Live Activity / watchOS surface. Can be layered on later.
- Quick-edit of target from the streaks screen (Q6 option C). Future work.

## Data model

### Domain: `RoutineTemplate`

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
    public var weeklyTarget: Int?        // NEW — nil = not tracked, 1...7 = target days per week
}
```

Initializer gains a `weeklyTarget: Int? = nil` parameter (kept last so call sites don't change).

### Persistence: `PersistedRoutineTemplate`

Add:

```swift
public var weeklyTarget: Int?
```

`init(from:)`, `toDomainModel()`, and `update(from:)` all read/write this field. SwiftData auto-migrates the new optional property; no migration code required.

### No new tables

Streak statistics are derived from existing `PersistedRoutineSession` records filtered by `template.id` with `completedAt != nil`. A routine with 1 year of daily use is ~365 sessions — scanning and bucketing per-day is trivially fast.

## `StreakCalculator`

Pure, stateless, `Sendable`. Lives in `Sources/HabitTrackerFeature/Services/StreakCalculator.swift`.

```swift
public struct StreakCalculator {

    public struct WeekStats: Sendable, Equatable {
        public let weekStart: Date              // Monday 00:00 local
        public let completionsPerDay: [Int]     // 7 ints, index 0 = Monday

        public var completedDayCount: Int {
            completionsPerDay.filter { $0 > 0 }.count
        }

        public func meetsTarget(_ target: Int) -> Bool {
            completedDayCount >= target
        }
    }

    public struct RoutineStreakData: Sendable, Identifiable {
        public var id: UUID { template.id }
        public let template: RoutineTemplate
        public let target: Int                  // non-nil, unwrapped
        public let currentWeek: WeekStats
        public let previousWeeks: [WeekStats]   // up to 4, newest-first
        public let extendedStreakBeyond: Int    // consecutive met weeks older than previousWeeks
        public let totalStreak: Int             // consecutive met prior weeks (excluding current)
    }

    public static func compute(
        for template: RoutineTemplate,
        sessions: [PersistedRoutineSession],
        now: Date,
        calendar: Calendar
    ) -> RoutineStreakData?
}
```

### Algorithm

1. If `template.weeklyTarget == nil`, return `nil`.
2. Build a Monday-first `Calendar` (`calendar.firstWeekday = 2`, `calendar.minimumDaysInFirstWeek = 4`).
3. Filter sessions: only those with `session.template?.id == template.id` and `completedAt != nil`.
4. Bucket into `[weekStart: [weekdayIndex: count]]`.
5. Build `currentWeek` for the week containing `now`.
6. Walk backwards from the week before `now` to build `previousWeeks` (up to 4).
7. Compute `totalStreak`: walk backwards week-by-week starting at `-1w`, counting consecutive weeks where `meetsTarget(target)`, stop on first miss. (A week with no sessions has `completedDayCount == 0` and fails any target ≥ 1, so it breaks the streak naturally — no special "no data" case needed.)
8. `extendedStreakBeyond = max(0, totalStreak - previousWeeks.count)`. Because the streak walks contiguously back from `-1w`, any streak longer than the 4 shown weeks must have all 4 visible weeks met, so this simple subtraction is correct.

### Edge cases

- **No sessions yet** → `currentWeek` zeros, `previousWeeks` = 4 empty weeks (each with ratio `0/target`, red), `totalStreak = 0`.
- **Week with zero sessions** counts as a miss and breaks the streak (standard behavior).
- **Fewer than 4 prior weeks since routine creation** → still return 4 empty `WeekStats` for consistent UI (red bars, `0/target`). Alternative discussed but rejected: returning fewer and making the view handle variable counts adds UI branches for no real gain.
- **DST transitions** → `Calendar.date(byAdding: .weekOfYear, value: -1, to: weekStart)` handles DST correctly; we use week arithmetic, never raw `TimeInterval`.
- **Sessions whose `completedAt` falls exactly on a week boundary** → `Calendar.dateInterval(of: .weekOfYear, for:)` uses half-open intervals, so Monday 00:00 belongs to the new week.

## UI

### `StreaksView`

New file: `Sources/HabitTrackerFeature/Views/StreaksView.swift`.

```swift
@MainActor
struct StreaksView: View {
    @Environment(RoutineService.self) private var routineService
    @State private var streaks: [StreakCalculator.RoutineStreakData] = []

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(streaks) { RoutineStreakCard(data: $0) }
            }
            .padding()
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Streaks")
        .task(id: routineService.currentSession == nil) {
            streaks = await routineService.computeStreaks(now: Date())
        }
        .overlay { if streaks.isEmpty { emptyState } }
    }
}
```

`RoutineService.computeStreaks(now:)` is a new `@MainActor` method that:
1. Fetches all `PersistedRoutineTemplate` where `weeklyTarget != nil`.
2. Fetches their sessions.
3. Converts templates to domain models and maps via `StreakCalculator.compute`.
4. Sorts by `template.lastUsedAt` descending (most recently used first), nil last.

### `RoutineStreakCard`

Visual spec matches `.superpowers/brainstorm/*/content/layout-v3.html`. Structure:

```
HStack (card, rounded 12pt, 14pt padding, bg = Theme.cardBackground)
├─ VStack header
│  ├─ Name (bold)
│  └─ 🔥 N week streak (if totalStreak > 0)
└─ HStack (gap 14pt)
   ├─ VStack (previous column, width 104)
   │  ├─ "PREVIOUS" label
   │  ├─ ForEach previousWeeks: week-row (label · bar · ratio)
   │  └─ if extendedStreakBeyond > 0: "🔥 +N more" pill
   └─ VStack (current week, flex)
      ├─ "THIS WEEK · N / target" label
      ├─ LazyHGrid(rows: 1, 7 cells)
      └─ day-letter row (M T W T F S S)
```

Day squares render as rounded 4pt rectangles:

- `count == 0` AND day is in the past or is today: `Color(Theme.streakEmpty)` (dark gray).
- `count == 0` AND day is in the future: `Color(Theme.streakEmpty).opacity(0.3)`.
- `count == 1`: green fill, no text.
- `count >= 2`: green fill with the count as black bold text, centered.

### Accessibility

- Each day square: `.accessibilityLabel("\(weekdayName), \(count) \(count == 1 ? "session" : "sessions")")` or `"not completed"` for zero counts. Future days: `"future day"`.
- Each prior-week bar: `"Week of \(formattedDate), \(metCount) of \(target) days completed, target \(meetsTarget ? "met" : "missed")"`.
- The streak pill: `"Plus \(n) more consecutive weeks meeting target"`.

### Theme

- Introduce `Theme.streakMet` (system green) and `Theme.streakMissed` (system red) if equivalents aren't already in `Theme`. Reuse existing `Theme.cardBackground` / `Theme.background`.

## Navigation integration

In `SmartTemplateSelectionView`:

1. Add a toolbar button next to `SettingsButton()` with `Image(systemName: "chart.bar.fill")` (or `"flame"`). `NavigationLink` pushes `StreaksView()`.
2. Add a drag gesture to the root `VStack`:

   ```swift
   .gesture(
       DragGesture(minimumDistance: 20)
           .onEnded { value in
               if value.translation.width < -80 && abs(value.translation.height) < 50 {
                   navigateToStreaks = true
               }
           }
   )
   .navigationDestination(isPresented: $navigateToStreaks) { StreaksView() }
   ```

Both paths use the existing `NavigationStack` already present in the view. Back-swipe / nav bar back button returns as normal.

Streaks are **not** reachable while `RoutineExecutionView` is showing (by design — you see them from the home screen).

## Routine Builder hook

In `RoutineBuilderView` add a new `Section("Streak tracking")` with:

```swift
Toggle("Track streak", isOn: Binding(
    get: { draft.weeklyTarget != nil },
    set: { draft.weeklyTarget = $0 ? (draft.weeklyTarget ?? 3) : nil }
))
if let target = draft.weeklyTarget {
    Stepper(
        "Weekly target: \(target)×",
        value: Binding(
            get: { draft.weeklyTarget ?? 3 },
            set: { draft.weeklyTarget = $0 }
        ),
        in: 1...7
    )
}
```

Saved through the existing builder save path — no `RoutineService` changes.

## Testing

`HabitTrackerPackage/Tests/HabitTrackerFeatureTests/StreakCalculatorTests.swift` (Swift Testing, new file):

- `weeklyTargetNilReturnsNil`
- `emptyHistoryYieldsZeros`
- `currentWeekCountsOnlyFinishedSessions` — pending sessions excluded.
- `currentWeekDayCountIgnoresDuplicates` — Q4: two sessions same day → `completedDayCount == 1`, `completionsPerDay[day] == 2`.
- `priorWeeksLimitedToFour`
- `targetMetThreeWeeksThenMissed` → `totalStreak == 3, extendedStreakBeyond == 0`.
- `targetMetTenConsecutiveWeeks` → `totalStreak == 10, previousWeeks[0...3]` all met, `extendedStreakBeyond == 6`.
- `weekBoundaryMondayFirst` — sessions at Sun 23:59 vs Mon 00:01 bucket correctly.
- `dstTransitionDoesNotSkipWeek` — spring-forward / fall-back week boundaries remain correct.
- `futureDaysNotCountedAgainstTarget` — current week `completionsPerDay` only reflects days ≤ `now`.
- `historicalTargetChangesReEvaluate` — Q7: a week with 4 completions is red when current target is 5, even if target was 3 at the time.

No UI tests per project policy (manual UI verification).

## File changes summary

| File | Change |
|------|--------|
| `Models/RoutineTemplate.swift` | Add `weeklyTarget: Int?` + init param. |
| `Models/SwiftDataModels.swift` | Add `weeklyTarget: Int?` to `PersistedRoutineTemplate`; update `init(from:)`, `toDomainModel()`, `update(from:)`. |
| `Services/StreakCalculator.swift` | **New.** Pure compute. |
| `Services/RoutineService.swift` | Add `computeStreaks(now:) async -> [StreakCalculator.RoutineStreakData]`. |
| `Views/StreaksView.swift` | **New.** List + empty state. |
| `Views/Components/RoutineStreakCard.swift` | **New.** Per-routine card. |
| `Views/SmartTemplateSelectionView.swift` | Add toolbar chart icon + swipe-left gesture + navigation destination. |
| `Views/RoutineBuilderView.swift` | Add "Streak tracking" section. |
| `Utils/Theme.swift` | Add `streakMet` / `streakMissed` / `streakEmpty` tokens if missing. |
| `Tests/HabitTrackerFeatureTests/StreakCalculatorTests.swift` | **New.** Unit tests. |

## Open questions / assumptions

- Assumed dark-theme palette in mockups; the view uses existing `Theme` tokens so it'll adapt to light mode automatically. If `Theme` doesn't already have card/streak colors matching the mockup, we add them.
- Assumed `RoutineService` can synchronously fetch `PersistedRoutineTemplate` with their sessions via `ModelContext`. If the current service abstracts fetches asynchronously, `computeStreaks` becomes `async` (already marked async above).
- Routine deletion behavior: deleting a template removes it from the streaks list. Sessions cascade is the existing behavior — no change.
