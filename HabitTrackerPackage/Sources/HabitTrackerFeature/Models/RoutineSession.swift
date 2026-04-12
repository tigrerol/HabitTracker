import Foundation

/// Represents an active morning routine session
@MainActor
@Observable
public final class RoutineSession: Equatable {
    public let id: UUID
    public let template: RoutineTemplate
    public let startedAt: Date
    public private(set) var completedAt: Date?
    public private(set) var currentHabitIndex: Int
    public private(set) var completions: [HabitCompletion]
    public private(set) var modifications: [SessionModification]

    /// Accumulated active time from prior segments (before pauses)
    public private(set) var priorActiveTime: TimeInterval

    /// Timestamp when the current active segment started (for tracking active time across pauses)
    public let segmentStartedAt: Date

    /// Per-habit timer state (keyed by habit UUID string) — updated live by TimerHabitView so it survives pause/resume
    public private(set) var timerStates: [String: TimerHabitState] = [:]

    public init(template: RoutineTemplate) {
        self.id = UUID()
        self.template = template
        self.startedAt = Date()
        self.segmentStartedAt = Date()
        self.completedAt = nil
        self.currentHabitIndex = 0
        self.completions = []
        self.modifications = []
        self.priorActiveTime = 0
    }

    /// Restore a session from a paused snapshot
    public init(from snapshot: PausedSessionSnapshot) {
        self.id = snapshot.id
        self.template = snapshot.template
        self.startedAt = snapshot.startedAt
        self.segmentStartedAt = Date()
        self.completedAt = nil
        self.currentHabitIndex = snapshot.currentHabitIndex
        self.completions = snapshot.completions
        self.modifications = snapshot.modifications
        self.priorActiveTime = snapshot.accumulatedActiveTime
        self.timerStates = snapshot.timerStates
    }

    /// Called by TimerHabitView on every tick/state-change to keep timer progress available for snapshot
    public func updateTimerState(habitId: UUID, state: TimerHabitState) {
        timerStates[habitId.uuidString] = state
    }
    
    /// Current habit being worked on
    public var currentHabit: Habit? {
        let habits = activeHabits
        guard currentHabitIndex >= 0 && currentHabitIndex < habits.count else { return nil }
        return habits[currentHabitIndex]
    }
    
    /// All active habits for this session (including modifications)
    public var activeHabits: [Habit] {
        var habits = template.habits.filter { $0.isActive }
        
        // Apply modifications
        for modification in modifications {
            switch modification.type {
            case .added(let habit):
                habits.append(habit)
            case .removed(let habitId):
                habits.removeAll { $0.id == habitId }
            case .modified(let habitId, let newHabit):
                if let index = habits.firstIndex(where: { $0.id == habitId }) {
                    habits[index] = newHabit
                }
            case .reordered(let newOrder):
                habits = newOrder
            }
        }
        
        return habits.sorted { $0.order < $1.order }
    }
    
    /// Progress percentage (0.0 to 1.0)
    public var progress: Double {
        guard !activeHabits.isEmpty else { return 1.0 }
        return Double(completions.count) / Double(activeHabits.count)
    }
    
    /// Whether the session is completed
    public var isCompleted: Bool {
        completedAt != nil
    }
    
    /// Total active session duration (excludes paused intervals)
    public var duration: TimeInterval {
        let currentSegmentTime: TimeInterval
        if let completedAt {
            currentSegmentTime = completedAt.timeIntervalSince(segmentStartedAt)
        } else {
            currentSegmentTime = Date().timeIntervalSince(segmentStartedAt)
        }
        return priorActiveTime + currentSegmentTime
    }

    /// Create a snapshot for pausing this session
    public func toPausedSnapshot() -> PausedSessionSnapshot {
        let currentSegmentTime = Date().timeIntervalSince(segmentStartedAt)
        return PausedSessionSnapshot(
            id: id,
            templateId: template.id,
            template: template,
            startedAt: startedAt,
            pausedAt: Date(),
            currentHabitIndex: currentHabitIndex,
            completions: completions,
            modifications: modifications,
            activeHabitsSnapshot: activeHabits,
            accumulatedActiveTime: priorActiveTime + currentSegmentTime,
            timerStates: timerStates
        )
    }
    
    // MARK: - Equatable
    public nonisolated static func == (lhs: RoutineSession, rhs: RoutineSession) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Session Actions
extension RoutineSession {
    /// Complete the current habit
    public func completeCurrentHabit(duration: TimeInterval? = nil, notes: String? = nil) {
        guard let habitToComplete = currentHabit else { return }
        
        // Check if this habit is already completed (can happen with conditional habits)
        let existingCompletion = completions.first { $0.habitId == habitToComplete.id }
        if existingCompletion != nil {
            // Already completed, just advance the index if needed
            let habitCount = activeHabits.count
            if currentHabitIndex < habitCount - 1 {
                currentHabitIndex += 1
            } else {
                // Session completed
                completedAt = Date()
            }
            return
        }
        
        let completion = HabitCompletion(
            habitId: habitToComplete.id,
            completedAt: Date(),
            duration: duration,
            notes: notes
        )
        
        completions.append(completion)
        
        // Move to next habit
        let habitCount = activeHabits.count
        if currentHabitIndex < habitCount - 1 {
            currentHabitIndex += 1
        } else {
            // Session completed
            completedAt = Date()
        }
    }
    
    /// Complete a conditional habit without auto-advancing the index
    /// This is used when path habits have been injected and should be executed next
    public func completeConditionalHabit(habitId: UUID, duration: TimeInterval? = nil, notes: String? = nil) {
        let completion = HabitCompletion(
            habitId: habitId,
            completedAt: Date(),
            duration: duration,
            notes: notes
        )
        
        completions.append(completion)
    }
    
    /// Skip the current habit
    public func skipCurrentHabit(reason: String? = nil) {
        guard let habitToSkip = currentHabit else { return }
        
        let completion = HabitCompletion(
            habitId: habitToSkip.id,
            completedAt: Date(),
            duration: 0,
            isSkipped: true,
            notes: reason
        )
        
        completions.append(completion)
        
        // Move to next habit
        let habitCount = activeHabits.count
        if currentHabitIndex < habitCount - 1 {
            currentHabitIndex += 1
        } else {
            // Session completed
            completedAt = Date()
        }
    }
    
    /// Go to previous habit
    public func goToPreviousHabit() {
        if currentHabitIndex > 0 {
            currentHabitIndex -= 1
            // Remove completion for this habit if it exists
            if let habitToModify = currentHabit {
                completions.removeAll { $0.habitId == habitToModify.id }
            }
        }
    }
    
    /// Jump to specific habit
    public func goToHabit(at index: Int) {
        let habitCount = activeHabits.count
        guard index >= 0 && index < habitCount else { return }
        currentHabitIndex = index
    }
    
    /// Add a habit to this session
    public func addHabit(_ habit: Habit) {
        let modification = SessionModification(
            type: .added(habit),
            timestamp: Date()
        )
        modifications.append(modification)
    }
    
    /// Remove a habit from this session
    public func removeHabit(withId id: UUID) {
        let modification = SessionModification(
            type: .removed(id),
            timestamp: Date()
        )
        modifications.append(modification)
    }
    
    /// Reorder habits in this session
    public func reorderHabits(_ newOrder: [Habit]) {
        let modification = SessionModification(
            type: .reordered(newOrder),
            timestamp: Date()
        )
        modifications.append(modification)
    }
    
    /// Force complete the session (used by RoutineService for manual completion)
    public func forceComplete() {
        if completedAt == nil {
            completedAt = Date()
        }
    }
}

// MARK: - Timer Habit State

/// Snapshot of a timer habit's in-progress state, so the timer position survives session pause/resume
public struct TimerHabitState: Codable, Sendable {
    public var timeRemaining: TimeInterval
    public var timeElapsed: TimeInterval
    public var currentStepIndex: Int
    public var currentRound: Int
    public var totalElapsed: TimeInterval
}

// MARK: - Paused Session Snapshot

/// A Codable snapshot of a paused routine session for persistence
public struct PausedSessionSnapshot: Codable, Identifiable, Sendable {
    public let id: UUID
    public let templateId: UUID
    public let template: RoutineTemplate
    public let startedAt: Date
    public let pausedAt: Date
    public var currentHabitIndex: Int
    public var completions: [HabitCompletion]
    public var modifications: [SessionModification]
    public var activeHabitsSnapshot: [Habit]
    public var accumulatedActiveTime: TimeInterval
    /// Per-habit timer state at the moment the session was paused (keyed by habit UUID string)
    public var timerStates: [String: TimerHabitState]

    public init(
        id: UUID,
        templateId: UUID,
        template: RoutineTemplate,
        startedAt: Date,
        pausedAt: Date,
        currentHabitIndex: Int,
        completions: [HabitCompletion],
        modifications: [SessionModification],
        activeHabitsSnapshot: [Habit],
        accumulatedActiveTime: TimeInterval,
        timerStates: [String: TimerHabitState] = [:]
    ) {
        self.id = id
        self.templateId = templateId
        self.template = template
        self.startedAt = startedAt
        self.pausedAt = pausedAt
        self.currentHabitIndex = currentHabitIndex
        self.completions = completions
        self.modifications = modifications
        self.activeHabitsSnapshot = activeHabitsSnapshot
        self.accumulatedActiveTime = accumulatedActiveTime
        self.timerStates = timerStates
    }

    // Custom decoder: timerStates may be absent in snapshots saved before this field was added
    private enum CodingKeys: String, CodingKey {
        case id, templateId, template, startedAt, pausedAt, currentHabitIndex
        case completions, modifications, activeHabitsSnapshot, accumulatedActiveTime, timerStates
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        templateId = try c.decode(UUID.self, forKey: .templateId)
        template = try c.decode(RoutineTemplate.self, forKey: .template)
        startedAt = try c.decode(Date.self, forKey: .startedAt)
        pausedAt = try c.decode(Date.self, forKey: .pausedAt)
        currentHabitIndex = try c.decode(Int.self, forKey: .currentHabitIndex)
        completions = try c.decode([HabitCompletion].self, forKey: .completions)
        modifications = try c.decode([SessionModification].self, forKey: .modifications)
        activeHabitsSnapshot = try c.decode([Habit].self, forKey: .activeHabitsSnapshot)
        accumulatedActiveTime = try c.decode(TimeInterval.self, forKey: .accumulatedActiveTime)
        timerStates = try c.decodeIfPresent([String: TimerHabitState].self, forKey: .timerStates) ?? [:]
    }

    /// Progress percentage (0.0 to 1.0)
    public var progress: Double {
        guard !activeHabitsSnapshot.isEmpty else { return 1.0 }
        return Double(completions.count) / Double(activeHabitsSnapshot.count)
    }

    /// Number of completed habits
    public var completedCount: Int {
        completions.count
    }

    /// Total number of habits
    public var totalCount: Int {
        activeHabitsSnapshot.count
    }
}