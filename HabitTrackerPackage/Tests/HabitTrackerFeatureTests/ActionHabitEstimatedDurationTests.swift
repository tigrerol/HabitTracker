import Testing
import Foundation
@testable import HabitTrackerFeature

@Suite("Action Habit Estimated Duration")
struct ActionHabitEstimatedDurationTests {

    // MARK: - Custom Duration

    @Test("Custom duration is used when set")
    func customDurationUsed() {
        let habit = Habit(
            name: "Open Journal",
            type: .action(type: .app, identifier: "journal://", displayName: "Journal", estimatedDuration: 600)
        )
        #expect(habit.estimatedDuration == 600)
    }

    @Test("Custom duration overrides app default")
    func customDurationOverridesAppDefault() {
        let habit = Habit(
            name: "Quick App",
            type: .action(type: .app, identifier: "app://", displayName: "App", estimatedDuration: 60)
        )
        // Default for app is 300, but custom is 60
        #expect(habit.estimatedDuration == 60)
    }

    @Test("Custom duration overrides website default")
    func customDurationOverridesWebsiteDefault() {
        let habit = Habit(
            name: "Read Article",
            type: .action(type: .website, identifier: "https://example.com", displayName: "Example", estimatedDuration: 900)
        )
        // Default for website is 180, but custom is 900
        #expect(habit.estimatedDuration == 900)
    }

    @Test("Custom duration overrides shortcut default")
    func customDurationOverridesShortcutDefault() {
        let habit = Habit(
            name: "Run Automation",
            type: .action(type: .shortcut, identifier: "My Shortcut", displayName: "Automation", estimatedDuration: 30)
        )
        // Default for shortcut is 120, but custom is 30
        #expect(habit.estimatedDuration == 30)
    }

    // MARK: - Nil Duration (Fallback to Defaults)

    @Test("Nil duration falls back to app default (300s)")
    func nilDurationFallsBackToAppDefault() {
        let habit = Habit(
            name: "Launch App",
            type: .action(type: .app, identifier: "app://", displayName: "App")
        )
        #expect(habit.estimatedDuration == 300)
    }

    @Test("Nil duration falls back to website default (180s)")
    func nilDurationFallsBackToWebsiteDefault() {
        let habit = Habit(
            name: "Open Website",
            type: .action(type: .website, identifier: "https://example.com", displayName: "Site")
        )
        #expect(habit.estimatedDuration == 180)
    }

    @Test("Nil duration falls back to shortcut default (120s)")
    func nilDurationFallsBackToShortcutDefault() {
        let habit = Habit(
            name: "Run Shortcut",
            type: .action(type: .shortcut, identifier: "shortcut", displayName: "Shortcut")
        )
        #expect(habit.estimatedDuration == 120)
    }

    @Test("Explicit nil duration falls back to defaults")
    func explicitNilFallsBack() {
        let habit = Habit(
            name: "Launch App",
            type: .action(type: .app, identifier: "app://", displayName: "App", estimatedDuration: nil)
        )
        #expect(habit.estimatedDuration == 300)
    }

    // MARK: - Codable Round-Trip

    @Test("Codable round-trip with custom duration preserves value")
    func codableRoundTripWithDuration() throws {
        let original = HabitType.action(type: .app, identifier: "journal://", displayName: "Journal", estimatedDuration: 600)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(HabitType.self, from: data)
        #expect(decoded == original)
    }

    @Test("Codable round-trip without duration preserves nil")
    func codableRoundTripWithoutDuration() throws {
        let original = HabitType.action(type: .website, identifier: "https://example.com", displayName: "Example")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(HabitType.self, from: data)
        #expect(decoded == original)
    }

    @Test("Full habit Codable round-trip with custom duration")
    func fullHabitCodableRoundTrip() throws {
        let original = Habit(
            name: "Journal",
            type: .action(type: .app, identifier: "journal://", displayName: "Journal", estimatedDuration: 900),
            color: "#FF3B30"
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Habit.self, from: data)
        #expect(decoded.name == original.name)
        #expect(decoded.type == original.type)
        #expect(decoded.estimatedDuration == 900)
    }
}
