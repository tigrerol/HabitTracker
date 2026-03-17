import Testing
import Foundation
@testable import HabitTrackerFeature

@Suite("Multi Day Category Tests")
struct MultiCategoryTests {

    // MARK: - DayCategorySettings Tests

    @Test("Multiple categories per weekday are stored and retrieved")
    func multipleCategories() {
        var settings = DayCategorySettings()
        settings.setCategories(Set(["weekday", "weekend"]), for: .monday)

        let categories = settings.categories(for: .monday)
        let ids = Set(categories.map(\.id))
        #expect(ids == Set(["weekday", "weekend"]))
    }

    @Test("Default categories for weekday and weekend")
    func defaultCategories() {
        let settings = DayCategorySettings()

        let mondayCategories = settings.categories(for: .monday)
        #expect(mondayCategories.count == 1)
        #expect(mondayCategories.first?.id == "weekday")

        let saturdayCategories = settings.categories(for: .saturday)
        #expect(saturdayCategories.count == 1)
        #expect(saturdayCategories.first?.id == "weekend")
    }

    @Test("getCurrentCategories returns categories for current day")
    func getCurrentCategories() {
        let settings = DayCategorySettings()
        let categories = settings.getCurrentCategories()
        #expect(!categories.isEmpty)
    }

    @Test("Delete category removes it from weekday assignments")
    func deleteCategory() {
        var settings = DayCategorySettings()
        let custom = DayCategory(id: "training", name: "Training", icon: "dumbbell", color: .red, isBuiltIn: false)
        settings.addCustomCategory(custom)
        settings.setCategories(Set(["weekday", "training"]), for: .monday)

        settings.deleteCustomCategory(withId: "training")

        let mondayCategories = settings.categories(for: .monday)
        let ids = Set(mondayCategories.map(\.id))
        #expect(!ids.contains("training"))
        #expect(!ids.isEmpty)
    }

    @Test("Delete last category from weekday falls back to default")
    func deleteLastCategoryFallback() {
        var settings = DayCategorySettings()
        let custom = DayCategory(id: "training", name: "Training", icon: "dumbbell", color: .red, isBuiltIn: false)
        settings.addCustomCategory(custom)
        settings.setCategories(Set(["training"]), for: .monday)

        settings.deleteCustomCategory(withId: "training")

        let mondayCategories = settings.categories(for: .monday)
        #expect(!mondayCategories.isEmpty)
        // Should fall back to default for Monday (weekday)
        #expect(mondayCategories.first?.id == "weekday")
    }

    @Test("Summary groups weekdays by category sets")
    func summary() {
        var settings = DayCategorySettings()
        settings.setCategories(Set(["weekday"]), for: .monday)
        settings.setCategories(Set(["weekday"]), for: .tuesday)
        settings.setCategories(Set(["weekend"]), for: .saturday)
        settings.setCategories(Set(["weekend"]), for: .sunday)

        let summary = settings.summary
        #expect(!summary.isEmpty)
    }

    // MARK: - Codable Migration: DayCategorySettings

    @Test("DayCategorySettings migrates from old single-string format")
    func settingsMigrationFromOldFormat() throws {
        // Create settings in old format by encoding a helper struct
        // that matches the old schema: weekdayCategories: [Weekday: String]
        let oldSettings = OldDayCategorySettings(
            weekdayCategories: [
                .monday: "weekday",
                .tuesday: "weekday",
                .saturday: "weekend",
                .sunday: "weekend"
            ],
            customCategories: DayCategory.defaults
        )

        let data = try JSONEncoder().encode(oldSettings)
        let settings = try JSONDecoder().decode(DayCategorySettings.self, from: data)

        let mondayCategories = settings.categories(for: .monday)
        #expect(mondayCategories.count == 1)
        #expect(mondayCategories.first?.id == "weekday")

        let saturdayCategories = settings.categories(for: .saturday)
        #expect(saturdayCategories.count == 1)
        #expect(saturdayCategories.first?.id == "weekend")
    }

    @Test("DayCategorySettings round-trip encode/decode with multi-categories")
    func settingsRoundTrip() throws {
        var settings = DayCategorySettings()
        settings.setCategories(Set(["weekday", "weekend"]), for: .monday)
        settings.setCategories(Set(["weekend"]), for: .saturday)

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(DayCategorySettings.self, from: data)

        let mondayCategories = decoded.categories(for: .monday)
        let ids = Set(mondayCategories.map(\.id))
        #expect(ids == Set(["weekday", "weekend"]))

        let saturdayCategories = decoded.categories(for: .saturday)
        #expect(saturdayCategories.count == 1)
        #expect(saturdayCategories.first?.id == "weekend")
    }

    // MARK: - Codable Migration: RoutineContext

    @Test("RoutineContext migrates from old single dayCategory format")
    func contextMigrationFromOldFormat() throws {
        // Create context in old format using helper struct
        let oldContext = OldRoutineContext(
            timeSlot: .morning,
            dayCategory: .weekday,
            location: .home,
            timestamp: Date(timeIntervalSince1970: 0)
        )

        let data = try JSONEncoder().encode(oldContext)
        let context = try JSONDecoder().decode(RoutineContext.self, from: data)

        #expect(context.dayCategories.count == 1)
        #expect(context.dayCategories.first?.id == "weekday")
        #expect(context.timeSlot == .morning)
        #expect(context.location == .home)
    }

    @Test("RoutineContext round-trip encode/decode with multi-categories")
    func contextRoundTrip() throws {
        let context = RoutineContext(
            timeSlot: .morning,
            dayCategories: [.weekday, .weekend],
            location: .home
        )

        let data = try JSONEncoder().encode(context)
        let decoded = try JSONDecoder().decode(RoutineContext.self, from: data)

        #expect(decoded.dayCategories.count == 2)
        let ids = Set(decoded.dayCategories.map(\.id))
        #expect(ids == Set(["weekday", "weekend"]))
        #expect(decoded.timeSlot == .morning)
        #expect(decoded.location == .home)
    }

    // MARK: - RoutineContextRule Matching

    @Test("RoutineContextRule matches when any category in context matches")
    func ruleMatchesAnyCategory() {
        let rule = RoutineContextRule(
            timeSlots: [.morning],
            dayCategoryIds: Set(["training"]),
            locationIds: []
        )

        let training = DayCategory(id: "training", name: "Training", icon: "dumbbell", isBuiltIn: false)
        let context = RoutineContext(
            timeSlot: .morning,
            dayCategories: [.weekday, training],
            location: .home
        )

        let dayMatch = rule.dayCategoryIds.isEmpty || context.dayCategories.contains { rule.dayCategoryIds.contains($0.id) }
        #expect(dayMatch == true)
    }

    @Test("RoutineContextRule does not match when no category in context matches")
    func ruleDoesNotMatchNoCategory() {
        let rule = RoutineContextRule(
            timeSlots: [.morning],
            dayCategoryIds: Set(["training"]),
            locationIds: []
        )

        let context = RoutineContext(
            timeSlot: .morning,
            dayCategories: [.weekday, .weekend],
            location: .home
        )

        let dayMatch = context.dayCategories.contains { rule.dayCategoryIds.contains($0.id) }
        #expect(dayMatch == false)
    }

    @Test("RoutineContextRule with empty dayCategoryIds matches any context")
    func ruleEmptyCategoriesMatchesAll() {
        let rule = RoutineContextRule(
            timeSlots: [.morning],
            dayCategoryIds: [],
            locationIds: []
        )

        let context = RoutineContext(
            timeSlot: .morning,
            dayCategories: [.weekday],
            location: .home
        )

        let dayMatch = rule.dayCategoryIds.isEmpty || context.dayCategories.contains { rule.dayCategoryIds.contains($0.id) }
        #expect(dayMatch == true)
    }

    @Test("Multiple category assignment does not duplicate")
    func noDuplicateCategories() {
        var settings = DayCategorySettings()
        settings.setCategories(Set(["weekday", "weekday", "weekend"]), for: .monday)

        let categories = settings.categories(for: .monday)
        // Set guarantees uniqueness, so max 2
        #expect(categories.count == 2)
    }
}

// MARK: - Helper types for migration testing

/// Simulates the OLD DayCategorySettings format with single String per weekday
private struct OldDayCategorySettings: Codable {
    let weekdayCategories: [Weekday: String]
    let customCategories: [DayCategory]
}

/// Simulates the OLD RoutineContext format with single DayCategory
private struct OldRoutineContext: Codable {
    let timeSlot: TimeSlot
    let dayCategory: DayCategory
    let location: LocationType
    let timestamp: Date
}
