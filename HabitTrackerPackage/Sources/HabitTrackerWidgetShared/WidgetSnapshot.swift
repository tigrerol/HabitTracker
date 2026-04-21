import Foundation

public enum WidgetSharedConstants {
    public static let appGroupIdentifier = "group.com.tigrerol.habittracker"
    public static let snapshotFileName = "widget_snapshot.json"
}

public struct WidgetSnapshot: Codable, Sendable, Equatable {
    public struct TopRoutine: Codable, Sendable, Equatable {
        public let name: String
        public let habitCount: Int
        public let colorHex: String

        public init(name: String, habitCount: Int, colorHex: String) {
            self.name = name
            self.habitCount = habitCount
            self.colorHex = colorHex
        }
    }

    public struct PausedSession: Codable, Sendable, Equatable {
        public let routineName: String
        public let pausedAt: Date
        public let currentStepIndex: Int
        public let totalSteps: Int

        public init(routineName: String, pausedAt: Date, currentStepIndex: Int, totalSteps: Int) {
            self.routineName = routineName
            self.pausedAt = pausedAt
            self.currentStepIndex = currentStepIndex
            self.totalSteps = totalSteps
        }
    }

    public struct StreakEntry: Codable, Sendable, Equatable {
        public let routineName: String
        public let totalStreak: Int
        public let target: Int
        public let completedThisWeek: Int

        public init(routineName: String, totalStreak: Int, target: Int, completedThisWeek: Int) {
            self.routineName = routineName
            self.totalStreak = totalStreak
            self.target = target
            self.completedThisWeek = completedThisWeek
        }
    }

    public let generatedAt: Date
    public let topRoutine: TopRoutine?
    public let pausedSession: PausedSession?
    public let streaks: [StreakEntry]

    public init(
        generatedAt: Date,
        topRoutine: TopRoutine?,
        pausedSession: PausedSession?,
        streaks: [StreakEntry]
    ) {
        self.generatedAt = generatedAt
        self.topRoutine = topRoutine
        self.pausedSession = pausedSession
        self.streaks = streaks
    }

    public static let empty = WidgetSnapshot(
        generatedAt: .distantPast,
        topRoutine: nil,
        pausedSession: nil,
        streaks: []
    )
}
