import ActivityKit
import SwiftUI

// MARK: - Live Activity Attributes

public struct TimerActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public let habitName: String
        public let startTime: Date
        public let duration: TimeInterval
        public let currentProgress: Double
        public let isRunning: Bool
        public let habitColor: String // Hex color string for persistence
        public let timeRemaining: TimeInterval
        
        public init(
            habitName: String,
            startTime: Date,
            duration: TimeInterval,
            currentProgress: Double,
            isRunning: Bool,
            habitColor: String,
            timeRemaining: TimeInterval
        ) {
            self.habitName = habitName
            self.startTime = startTime
            self.duration = duration
            self.currentProgress = currentProgress
            self.isRunning = isRunning
            self.habitColor = habitColor
            self.timeRemaining = timeRemaining
        }
    }
    
    // Static attributes that don't change
    public let habitId: String
    
    public init(habitId: String) {
        self.habitId = habitId
    }
}

// MARK: - Time Formatting Extension

extension TimeInterval {
    public var formattedCountdown: String {
        guard self.isFinite, !self.isNaN else {
            return "00:00"
        }
        
        let totalSeconds = max(0, Int(self))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}