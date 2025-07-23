import Foundation

/// Represents an active morning routine session
@Observable
public final class RoutineSession: Sendable {
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
        guard currentHabitIndex < activeHabits.count else { return nil }
        return activeHabits[currentHabitIndex]
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
}

// MARK: - Session Actions
extension RoutineSession {
    /// Complete the current habit
    public func completeCurrentHabit(duration: TimeInterval? = nil, notes: String? = nil) {
        guard let currentHabit else { return }
        
        let completion = HabitCompletion(
            habitId: currentHabit.id,
            completedAt: Date(),
            duration: duration,
            notes: notes
        )
        
        completions.append(completion)
        
        // Move to next habit
        if currentHabitIndex < activeHabits.count - 1 {
            currentHabitIndex += 1
        } else {
            // Session completed
            completedAt = Date()
        }
    }
    
    /// Skip the current habit
    public func skipCurrentHabit(reason: String? = nil) {
        guard let currentHabit else { return }
        
        let completion = HabitCompletion(
            habitId: currentHabit.id,
            completedAt: Date(),
            duration: 0,
            isSkipped: true,
            notes: reason
        )
        
        completions.append(completion)
        
        // Move to next habit
        if currentHabitIndex < activeHabits.count - 1 {
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
            if let currentHabit {
                completions.removeAll { $0.habitId == currentHabit.id }
            }
        }
    }
    
    /// Jump to specific habit
    public func goToHabit(at index: Int) {
        guard index >= 0 && index < activeHabits.count else { return }
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
}