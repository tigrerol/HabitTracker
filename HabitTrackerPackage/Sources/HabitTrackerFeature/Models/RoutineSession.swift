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
    
    public init(template: RoutineTemplate) {
        self.id = UUID()
        self.template = template
        self.startedAt = Date()
        self.completedAt = nil
        self.currentHabitIndex = 0
        self.completions = []
        self.modifications = []
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
    
    /// Total session duration
    public var duration: TimeInterval {
        if let completedAt {
            return completedAt.timeIntervalSince(startedAt)
        } else {
            return Date().timeIntervalSince(startedAt)
        }
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
}