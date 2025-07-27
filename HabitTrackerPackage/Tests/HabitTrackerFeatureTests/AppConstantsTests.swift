import Testing
import Foundation
import CoreLocation
@testable import HabitTrackerFeature

@Suite("App Constants Tests")
struct AppConstantsTests {
    
    @Test("Animation durations are reasonable")
    func testAnimationDurations() {
        #expect(AppConstants.AnimationDurations.standard > 0)
        #expect(AppConstants.AnimationDurations.standard <= 1.0)
        
        #expect(AppConstants.AnimationDurations.quick > 0)
        #expect(AppConstants.AnimationDurations.quick < AppConstants.AnimationDurations.standard)
        
        #expect(AppConstants.AnimationDurations.habitCompletion > 0)
        #expect(AppConstants.AnimationDurations.habitCompletion <= 1.0)
        
        #expect(AppConstants.AnimationDurations.accessibilityDelay > 0)
        #expect(AppConstants.AnimationDurations.accessibilityDelay < AppConstants.AnimationDurations.quick)
    }
    
    @Test("Spacing values are properly ordered")
    func testSpacingValues() {
        #expect(AppConstants.Spacing.extraSmall < AppConstants.Spacing.small)
        #expect(AppConstants.Spacing.small < AppConstants.Spacing.standard)
        #expect(AppConstants.Spacing.standard < AppConstants.Spacing.medium)
        #expect(AppConstants.Spacing.medium < AppConstants.Spacing.large)
        #expect(AppConstants.Spacing.large < AppConstants.Spacing.extraLarge)
        #expect(AppConstants.Spacing.extraLarge < AppConstants.Spacing.section)
        #expect(AppConstants.Spacing.section < AppConstants.Spacing.page)
        
        // Check that all values are positive
        #expect(AppConstants.Spacing.extraSmall > 0)
        #expect(AppConstants.Spacing.page > 0)
    }
    
    @Test("Padding values are reasonable")
    func testPaddingValues() {
        #expect(AppConstants.Padding.small < AppConstants.Padding.medium)
        #expect(AppConstants.Padding.medium < AppConstants.Padding.large)
        #expect(AppConstants.Padding.large < AppConstants.Padding.extraLarge)
        #expect(AppConstants.Padding.extraLarge < AppConstants.Padding.section)
        
        // Check reasonable ranges
        #expect(AppConstants.Padding.small >= 4)
        #expect(AppConstants.Padding.section <= 50)
    }
    
    @Test("Corner radius values are properly ordered")
    func testCornerRadiusValues() {
        #expect(AppConstants.CornerRadius.small < AppConstants.CornerRadius.medium)
        #expect(AppConstants.CornerRadius.medium < AppConstants.CornerRadius.large)
        
        // Check reasonable ranges for UI elements
        #expect(AppConstants.CornerRadius.small >= 4)
        #expect(AppConstants.CornerRadius.large <= 30)
    }
    
    @Test("Font sizes are appropriate")
    func testFontSizes() {
        #expect(AppConstants.FontSizes.icon > 0)
        #expect(AppConstants.FontSizes.icon < AppConstants.FontSizes.largeIcon)
        #expect(AppConstants.FontSizes.largeIcon < AppConstants.FontSizes.extraLargeIcon)
        
        // Check reasonable ranges for icons
        #expect(AppConstants.FontSizes.icon >= 16)
        #expect(AppConstants.FontSizes.extraLargeIcon <= 120)
    }
    
    @Test("Location constants are valid")
    func testLocationConstants() {
        #expect(AppConstants.Location.defaultRadius > 0)
        #expect(AppConstants.Location.distanceFilter > 0)
        
        // Check reasonable values for location services
        #expect(AppConstants.Location.defaultRadius >= 50) // At least 50 meters
        #expect(AppConstants.Location.defaultRadius <= 1000) // Not more than 1km
        
        #expect(AppConstants.Location.distanceFilter >= 10) // At least 10 meters
        #expect(AppConstants.Location.distanceFilter <= 500) // Not more than 500m
    }
    
    @Test("Routine constants are reasonable")
    func testRoutineConstants() {
        #expect(AppConstants.Routine.defaultTemplatePriority > 0)
        #expect(AppConstants.Routine.priorityBoost > 0)
        
        // Check priority relationships
        #expect(AppConstants.Routine.priorityBoost > AppConstants.Routine.afternoonPriority)
        #expect(AppConstants.Routine.afternoonPriority >= AppConstants.Routine.defaultTemplatePriority)
        
        // Check all priorities are positive
        #expect(AppConstants.Routine.officePriority > 0)
        #expect(AppConstants.Routine.homeOfficePriority > 0)
        #expect(AppConstants.Routine.weekendPriority > 0)
    }
    
    @Test("Habit order constants are unique")
    func testHabitOrderUniqueness() {
        let officeOrders = [
            AppConstants.HabitOrder.hrv,
            AppConstants.HabitOrder.strength,
            AppConstants.HabitOrder.coffee,
            AppConstants.HabitOrder.supplements,
            AppConstants.HabitOrder.stretching,
            AppConstants.HabitOrder.shower,
            AppConstants.HabitOrder.workspace
        ]
        
        let uniqueOrders = Set(officeOrders)
        #expect(officeOrders.count == uniqueOrders.count)
        
        // Check orders are properly sequenced
        let sortedOrders = officeOrders.sorted()
        #expect(sortedOrders == officeOrders)
    }
    
    @Test("Weekend habit orders are unique")
    func testWeekendHabitOrderUniqueness() {
        let weekendOrders = [
            AppConstants.HabitOrder.weekendCoffee,
            AppConstants.HabitOrder.weekendSupplements,
            AppConstants.HabitOrder.weekendStretching,
            AppConstants.HabitOrder.weekendNews
        ]
        
        let uniqueOrders = Set(weekendOrders)
        #expect(weekendOrders.count == uniqueOrders.count)
    }
    
    @Test("Afternoon habit orders are unique")
    func testAfternoonHabitOrderUniqueness() {
        let afternoonOrders = [
            AppConstants.HabitOrder.goalsReview,
            AppConstants.HabitOrder.afternoonStretch,
            AppConstants.HabitOrder.healthySnack,
            AppConstants.HabitOrder.focusTime,
            AppConstants.HabitOrder.eveningPlanning
        ]
        
        let uniqueOrders = Set(afternoonOrders)
        #expect(afternoonOrders.count == uniqueOrders.count)
    }
    
    @Test("Grid constants are reasonable")
    func testGridConstants() {
        #expect(AppConstants.GridColumns.locationIcons > 0)
        #expect(AppConstants.GridColumns.locationIcons <= 10)
        
        // Should be reasonable for UI layout
        #expect(AppConstants.GridColumns.locationIcons >= 3)
    }
    
    @Test("Constants maintain consistency across categories")
    func testCrossCategoryConsistency() {
        // Spacing and padding should be related
        #expect(AppConstants.Spacing.standard <= AppConstants.Padding.medium)
        #expect(AppConstants.Spacing.large <= AppConstants.Padding.extraLarge)
        
        // Animation durations should be reasonable relative to each other
        #expect(AppConstants.AnimationDurations.accessibilityDelay < AppConstants.AnimationDurations.quick)
        #expect(AppConstants.AnimationDurations.quick < AppConstants.AnimationDurations.standard)
    }
    
    @Test("Constants are within acceptable ranges for production")
    func testProductionReadiness() {
        // Animation durations shouldn't be too slow for production
        #expect(AppConstants.AnimationDurations.standard <= 0.5)
        #expect(AppConstants.AnimationDurations.habitCompletion <= 1.0)
        
        // Spacing shouldn't be excessive
        #expect(AppConstants.Spacing.page <= 50)
        #expect(AppConstants.Padding.section <= 50)
        
        // Corner radius shouldn't be too extreme
        #expect(AppConstants.CornerRadius.large <= 25)
        
        // Location services should be battery-friendly
        #expect(AppConstants.Location.distanceFilter >= 50) // Don't update too frequently
    }
}

@Suite("Constants Usage Verification")
struct ConstantsUsageVerificationTests {
    
    @Test("Location constants match expected values")
    func testLocationConstantsValues() {
        // Verify the actual values are what we expect
        #expect(AppConstants.Location.defaultRadius == 150.0)
        #expect(AppConstants.Location.distanceFilter == 100.0)
    }
    
    @Test("Animation constants match expected values")
    func testAnimationConstantsValues() {
        #expect(AppConstants.AnimationDurations.standard == 0.3)
        #expect(AppConstants.AnimationDurations.quick == 0.2)
        #expect(AppConstants.AnimationDurations.habitCompletion == 0.5)
        #expect(AppConstants.AnimationDurations.accessibilityDelay == 0.1)
    }
    
    @Test("Priority constants match expected values")
    func testPriorityConstantsValues() {
        #expect(AppConstants.Routine.defaultTemplatePriority == 1)
        #expect(AppConstants.Routine.priorityBoost == 10)
        #expect(AppConstants.Routine.officePriority == 2)
        #expect(AppConstants.Routine.homeOfficePriority == 2)
        #expect(AppConstants.Routine.weekendPriority == 1)
        #expect(AppConstants.Routine.afternoonPriority == 3)
    }
    
    @Test("Habit order constants match expected sequence")
    func testHabitOrderSequence() {
        // Office routine order
        #expect(AppConstants.HabitOrder.hrv == 0)
        #expect(AppConstants.HabitOrder.strength == 1)
        #expect(AppConstants.HabitOrder.coffee == 2)
        #expect(AppConstants.HabitOrder.supplements == 3)
        #expect(AppConstants.HabitOrder.stretching == 4)
        #expect(AppConstants.HabitOrder.shower == 5)
        #expect(AppConstants.HabitOrder.workspace == 6)
        
        // Weekend routine order
        #expect(AppConstants.HabitOrder.weekendCoffee == 1)
        #expect(AppConstants.HabitOrder.weekendSupplements == 2)
        #expect(AppConstants.HabitOrder.weekendStretching == 3)
        #expect(AppConstants.HabitOrder.weekendNews == 4)
        
        // Afternoon routine order
        #expect(AppConstants.HabitOrder.goalsReview == 1)
        #expect(AppConstants.HabitOrder.afternoonStretch == 2)
        #expect(AppConstants.HabitOrder.healthySnack == 3)
        #expect(AppConstants.HabitOrder.focusTime == 4)
        #expect(AppConstants.HabitOrder.eveningPlanning == 5)
    }
}