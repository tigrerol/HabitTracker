import Foundation

/// Factory for creating common habits to eliminate code duplication across templates
public enum HabitFactory {
    
    // MARK: - Common Colors
    public enum Colors {
        public static let hrv = "#FF6B6B"
        public static let strength = "#4ECDC4"
        public static let coffee = "#8B4513"
        public static let supplements = "#FFD93D"
        public static let stretching = "#6BCF7F"
        public static let shower = "#74B9FF"
        public static let workspace = "#A29BFE"
        public static let goals = "#007AFF"
        public static let snack = "#FF9500"
        public static let focus = "#5856D6"
        public static let planning = "#FF3B30"
        public static let news = "#FF7675"
    }
    
    // MARK: - Common Durations
    public enum Durations {
        public static let shortStretch: TimeInterval = 600  // 10 minutes
        public static let mediumStretch: TimeInterval = 900 // 15 minutes
        public static let longStretch: TimeInterval = 1200  // 20 minutes
        public static let shortFocus: TimeInterval = 300    // 5 minutes
        public static let pomodoroFocus: TimeInterval = 1500 // 25 minutes
    }
    
    // MARK: - Common Supplement Lists
    public enum SupplementLists {
        public static let complete = ["Vitamin D", "Magnesium", "Omega-3"]
        public static let basic = ["Vitamin D", "Magnesium"]
        public static let minimal = ["Vitamin D"]
    }
    
    // MARK: - Common URLs
    public enum URLs {
        public static let workoutSite = URL(string: "https://your-workout-site.com")!
        public static let hackerNews = URL(string: "https://news.ycombinator.com")!
    }
    
    // MARK: - Factory Methods
    
    /// Create HRV measurement habit
    public static func createHRVHabit(order: Int = 0) -> Habit {
        Habit(
            name: "Measure HRV",
            type: .appLaunch(bundleId: "com.morpheus.app", appName: "Morpheus"),
            color: Colors.hrv,
            order: order
        )
    }
    
    /// Create strength training habit
    public static func createStrengthTrainingHabit(order: Int) -> Habit {
        Habit(
            name: "Strength Training",
            type: .website(url: URLs.workoutSite, title: "Workout Site"),
            color: Colors.strength,
            order: order
        )
    }
    
    /// Create coffee habit
    public static func createCoffeeHabit(order: Int) -> Habit {
        Habit(
            name: "Coffee",
            type: .task(subtasks: []),
            color: Colors.coffee,
            order: order
        )
    }
    
    /// Create supplements habit with configurable items
    public static func createSupplementsHabit(
        items: [String] = SupplementLists.complete,
        order: Int
    ) -> Habit {
        Habit(
            name: "Supplements",
            type: .counter(items: items),
            color: Colors.supplements,
            order: order
        )
    }
    
    /// Create stretching habit with configurable duration
    public static func createStretchingHabit(
        name: String = "Stretching",
        duration: TimeInterval = Durations.shortStretch,
        order: Int
    ) -> Habit {
        Habit(
            name: name,
            type: .timer(style: .down, duration: duration),
            color: Colors.stretching,
            order: order
        )
    }
    
    /// Create shower habit
    public static func createShowerHabit(order: Int) -> Habit {
        Habit(
            name: "Shower",
            type: .task(subtasks: []),
            color: Colors.shower,
            order: order
        )
    }
    
    /// Create workspace preparation habit
    public static func createWorkspaceHabit(order: Int) -> Habit {
        Habit(
            name: "Prep Workspace",
            type: .task(subtasks: []),
            color: Colors.workspace,
            order: order
        )
    }
    
    /// Create goals review habit
    public static func createGoalsReviewHabit(order: Int) -> Habit {
        Habit(
            name: "Review Daily Goals",
            type: .task(subtasks: []),
            color: Colors.goals,
            order: order
        )
    }
    
    /// Create healthy snack habit
    public static func createHealthySnackHabit(order: Int) -> Habit {
        Habit(
            name: "Healthy Snack",
            type: .task(subtasks: []),
            color: Colors.snack,
            order: order
        )
    }
    
    /// Create focus time habit with configurable duration
    public static func createFocusTimeHabit(
        duration: TimeInterval = Durations.pomodoroFocus,
        order: Int
    ) -> Habit {
        Habit(
            name: "Focus Time",
            type: .timer(style: .down, duration: duration),
            color: Colors.focus,
            order: order
        )
    }
    
    /// Create evening planning habit with subtasks
    public static func createEveningPlanningHabit(order: Int) -> Habit {
        let subtasks = [
            Subtask(name: "Review tomorrow's calendar"),
            Subtask(name: "Set top 3 priorities"),
            Subtask(name: "Prepare for meetings")
        ]
        
        return Habit(
            name: "Evening Planning",
            type: .task(subtasks: subtasks),
            color: Colors.planning,
            order: order
        )
    }
    
    /// Create news reading habit (optional)
    public static func createNewsReadingHabit(
        url: URL = URLs.hackerNews,
        title: String = "Hacker News",
        order: Int
    ) -> Habit {
        Habit(
            name: "Read News",
            type: .website(url: url, title: title),
            isOptional: true,
            color: Colors.news,
            order: order
        )
    }
    
    // MARK: - Template Builders
    
    /// Create a complete office morning routine
    public static func createOfficeMorningHabits() -> [Habit] {
        [
            createHRVHabit(order: 0),
            createStrengthTrainingHabit(order: 1),
            createCoffeeHabit(order: 2),
            createSupplementsHabit(order: 3),
            createStretchingHabit(duration: Durations.shortStretch, order: 4),
            createShowerHabit(order: 5)
        ]
    }
    
    /// Create a complete home office routine
    public static func createHomeOfficeHabits() -> [Habit] {
        [
            createHRVHabit(order: 0),
            createStrengthTrainingHabit(order: 1),
            createCoffeeHabit(order: 2),
            createSupplementsHabit(order: 3),
            createStretchingHabit(duration: Durations.mediumStretch, order: 4),
            createShowerHabit(order: 5),
            createWorkspaceHabit(order: 6)
        ]
    }
    
    /// Create a relaxed weekend routine
    public static func createWeekendHabits() -> [Habit] {
        [
            createHRVHabit(order: 0),
            createCoffeeHabit(order: 1),
            createSupplementsHabit(items: SupplementLists.basic, order: 2),
            createStretchingHabit(
                name: "Long Stretching", 
                duration: Durations.longStretch, 
                order: 3
            ),
            createNewsReadingHabit(order: 4)
        ]
    }
    
    /// Create an afternoon productivity routine
    public static func createAfternoonHabits() -> [Habit] {
        [
            createGoalsReviewHabit(order: 1),
            createStretchingHabit(
                name: "Afternoon Stretch",
                duration: Durations.shortFocus,
                order: 2
            ),
            createHealthySnackHabit(order: 3),
            createFocusTimeHabit(order: 4),
            createEveningPlanningHabit(order: 5)
        ]
    }
}