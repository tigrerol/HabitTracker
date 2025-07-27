import Foundation
import CoreLocation

/// Central location for all app-wide constants to improve maintainability
/// and prevent magic numbers scattered throughout the codebase
public enum AppConstants {
    
    // MARK: - UI Constants
    
    /// Animation durations used throughout the app
    public enum AnimationDurations {
        /// Standard animation duration for UI transitions
        public static let standard: TimeInterval = 0.3
        
        /// Quick animation for button interactions
        public static let quick: TimeInterval = 0.2
        
        /// Completion delay for habit interactions
        public static let habitCompletion: TimeInterval = 0.5
        
        /// Brief delay for accessibility announcements
        public static let accessibilityDelay: TimeInterval = 0.1
    }
    
    /// Common UI spacing values
    public enum Spacing {
        /// Extra small spacing (2-4pt)
        public static let extraSmall: CGFloat = 2
        public static let small: CGFloat = 4
        
        /// Standard spacing (8-12pt)
        public static let standard: CGFloat = 8
        public static let medium: CGFloat = 12
        
        /// Large spacing (16-24pt)
        public static let large: CGFloat = 16
        public static let extraLarge: CGFloat = 24
        
        /// Section spacing (32pt)
        public static let section: CGFloat = 32
        
        /// Page spacing (40pt)
        public static let page: CGFloat = 40
    }
    
    /// Common padding values
    public enum Padding {
        public static let small: CGFloat = 8
        public static let medium: CGFloat = 12
        public static let large: CGFloat = 16
        public static let extraLarge: CGFloat = 20
        public static let section: CGFloat = 32
    }
    
    /// Corner radius values
    public enum CornerRadius {
        public static let small: CGFloat = 8
        public static let medium: CGFloat = 12
        public static let large: CGFloat = 20
    }
    
    /// Font sizes for system fonts
    public enum FontSizes {
        public static let icon: CGFloat = 24
        public static let largeIcon: CGFloat = 60
        public static let extraLargeIcon: CGFloat = 80
    }
    
    // MARK: - Location Constants
    
    /// Location-related constants
    public enum Location {
        /// Default radius for location detection (meters)
        public static let defaultRadius: CLLocationDistance = 150
        
        /// Distance filter for location updates (meters)
        public static let distanceFilter: CLLocationDistance = 100
    }
    
    // MARK: - Routine Constants
    
    /// Routine and habit-related constants
    public enum Routine {
        /// Default priority for templates without context rules
        public static let defaultTemplatePriority: Int = 1
        
        /// Priority boost for scoring
        public static let priorityBoost: Int = 10
        
        /// Office template priority
        public static let officePriority: Int = 2
        
        /// Home office template priority  
        public static let homeOfficePriority: Int = 2
        
        /// Weekend template priority
        public static let weekendPriority: Int = 1
        
        /// Afternoon template priority
        public static let afternoonPriority: Int = 3
    }
    
    // MARK: - Habit Factory Constants
    
    /// Pre-defined habit order values for consistency
    public enum HabitOrder {
        // Office morning routine orders
        public static let hrv: Int = 0
        public static let strength: Int = 1
        public static let coffee: Int = 2
        public static let supplements: Int = 3
        public static let stretching: Int = 4
        public static let shower: Int = 5
        public static let workspace: Int = 6
        
        // Weekend routine orders  
        public static let weekendCoffee: Int = 1
        public static let weekendSupplements: Int = 2
        public static let weekendStretching: Int = 3
        public static let weekendNews: Int = 4
        
        // Afternoon routine orders
        public static let goalsReview: Int = 1
        public static let afternoonStretch: Int = 2
        public static let healthySnack: Int = 3
        public static let focusTime: Int = 4
        public static let eveningPlanning: Int = 5
    }
    
    // MARK: - Grid Constants
    
    /// Grid column counts for various layouts
    public enum GridColumns {
        /// Standard grid for location icons
        public static let locationIcons: Int = 5
    }
}