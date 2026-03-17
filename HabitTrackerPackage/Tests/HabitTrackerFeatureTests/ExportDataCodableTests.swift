import Testing
import Foundation
import CoreLocation
@testable import HabitTrackerFeature

@Suite("Export Data Codable Round-Trip Tests")
struct ExportDataCodableTests {

    // MARK: - Helpers

    private func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    private func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    // MARK: - ExportData Round-Trip

    @Test("ExportData with routines survives JSON round-trip")
    func testExportDataWithRoutines() throws {
        let habits = [
            Habit(name: "Meditate", type: .timer(style: .down, duration: 600), order: 0),
            Habit(name: "Exercise", type: .task(subtasks: [
                Subtask(name: "Push-ups"),
                Subtask(name: "Squats", isOptional: true)
            ]), order: 1),
            Habit(name: "Supplements", type: .tracking(.counter(items: ["Vitamin D", "Omega 3"])), order: 2)
        ]

        let original = ExportData(
            routines: [
                RoutineTemplate(name: "Morning", habits: habits, color: "#34C759"),
                RoutineTemplate(name: "Evening", habits: [
                    Habit(name: "Journal", type: .task(subtasks: []), order: 0)
                ])
            ],
            customLocations: [],
            savedLocations: [:],
            dayCategories: [],
            exportDate: Date(),
            appVersion: "1.0.0"
        )

        let data = try makeEncoder().encode(original)
        let decoded = try makeDecoder().decode(ExportData.self, from: data)

        #expect(decoded.routines.count == 2)
        #expect(decoded.routines[0].name == "Morning" || decoded.routines[1].name == "Morning")
        #expect(decoded.appVersion == "1.0.0")

        let morningRoutine = decoded.routines.first(where: { $0.name == "Morning" })!
        #expect(morningRoutine.habits.count == 3)

        let meditate = morningRoutine.habits.first(where: { $0.name == "Meditate" })
        #expect(meditate?.type == .timer(style: .down, duration: 600))
    }

    @Test("ExportData with all habit types round-trips correctly")
    func testExportAllHabitTypes() throws {
        let allTypeHabits = [
            Habit(name: "Task", type: .task(subtasks: [Subtask(name: "A")]), order: 0),
            Habit(name: "Timer Down", type: .timer(style: .down, duration: 300), order: 1),
            Habit(name: "Timer Up", type: .timer(style: .up, duration: 0, target: 600), order: 2),
            Habit(name: "Timer Multi", type: .timer(style: .multiple, duration: 0, steps: [
                SequenceStep(name: "Work", duration: 30),
                SequenceStep(name: "Rest", duration: 10)
            ], repeatCount: 4), order: 3),
            Habit(name: "App", type: .action(type: .app, identifier: "com.test", displayName: "Test"), order: 4),
            Habit(name: "Website", type: .action(type: .website, identifier: "https://test.com", displayName: "Test Site"), order: 5),
            Habit(name: "Shortcut", type: .action(type: .shortcut, identifier: "my-sc", displayName: "SC"), order: 6),
            Habit(name: "Counter", type: .tracking(.counter(items: ["A", "B"])), order: 7),
            Habit(name: "Measure", type: .tracking(.measurement(unit: "kg", targetValue: 75.0)), order: 8),
            Habit(name: "Sequence", type: .guidedSequence(steps: [SequenceStep(name: "S1", duration: 60)]), order: 9),
            Habit(name: "Question", type: .conditional(ConditionalHabitInfo(
                question: "How?",
                options: [ConditionalOption(text: "Good", habits: [Habit(name: "Hard", type: .task(subtasks: []), createdAt: Date(timeIntervalSince1970: 1710000000))])]
            )), order: 10, createdAt: Date(timeIntervalSince1970: 1710000000))
        ]

        let original = ExportData(
            routines: [RoutineTemplate(name: "All Types", habits: allTypeHabits)],
            customLocations: [],
            savedLocations: [:],
            dayCategories: [],
            exportDate: Date(),
            appVersion: "1.0.0"
        )

        let data = try makeEncoder().encode(original)
        let decoded = try makeDecoder().decode(ExportData.self, from: data)

        let routine = decoded.routines[0]
        #expect(routine.habits.count == 11)

        // Verify each type survived
        for (orig, dec) in zip(allTypeHabits.sorted(by: { $0.order < $1.order }),
                               routine.habits.sorted(by: { $0.order < $1.order })) {
            #expect(dec.name == orig.name, "Name mismatch for order \(orig.order)")
            #expect(dec.type == orig.type, "Type mismatch for \(orig.name)")
        }
    }

    @Test("ExportData with saved locations round-trips correctly")
    func testExportSavedLocations() throws {
        let home = SavedLocation(
            location: CLLocation(latitude: 48.2082, longitude: 16.3738),
            name: "Home",
            radius: 150
        )
        let office = SavedLocation(
            location: CLLocation(latitude: 48.1951, longitude: 16.3700),
            name: "Office",
            radius: 200
        )

        let original = ExportData(
            routines: [],
            customLocations: [],
            savedLocations: [.home: home, .office: office],
            dayCategories: [],
            exportDate: Date(),
            appVersion: "1.0.0"
        )

        let data = try makeEncoder().encode(original)
        let decoded = try makeDecoder().decode(ExportData.self, from: data)

        #expect(decoded.savedLocations.count == 2)
        #expect(decoded.savedLocations[.home]?.name == "Home")
        #expect(decoded.savedLocations[.office]?.name == "Office")

        let decodedHome = decoded.savedLocations[.home]!
        #expect(abs(decodedHome.coordinate.latitude - 48.2082) < 0.0001)
        #expect(abs(decodedHome.coordinate.longitude - 16.3738) < 0.0001)
        #expect(decodedHome.radius == 150)
    }

    @Test("ExportData with custom locations round-trips correctly")
    func testExportCustomLocations() throws {
        let original = ExportData(
            routines: [],
            customLocations: [
                CustomLocation(name: "Gym", icon: "dumbbell.fill", coordinate: LocationCoordinate(latitude: 48.0, longitude: 16.0), radius: 100),
                CustomLocation(name: "Park", icon: "leaf.fill", coordinate: nil, radius: 200)
            ],
            savedLocations: [:],
            dayCategories: [],
            exportDate: Date(),
            appVersion: "1.0.0"
        )

        let data = try makeEncoder().encode(original)
        let decoded = try makeDecoder().decode(ExportData.self, from: data)

        #expect(decoded.customLocations.count == 2)

        let gym = decoded.customLocations.first(where: { $0.name == "Gym" })
        #expect(gym?.icon == "dumbbell.fill")
        #expect(gym?.coordinate?.latitude == 48.0)
        #expect(gym?.radius == 100)

        let park = decoded.customLocations.first(where: { $0.name == "Park" })
        #expect(park?.coordinate == nil)
    }

    @Test("ExportData with day categories round-trips correctly")
    func testExportDayCategories() throws {
        let original = ExportData(
            routines: [],
            customLocations: [],
            savedLocations: [:],
            dayCategories: [
                DayCategory(name: "Workday", icon: "briefcase.fill", color: .blue),
                DayCategory(name: "Weekend", icon: "sun.max.fill", color: .orange)
            ],
            exportDate: Date(),
            appVersion: "1.0.0"
        )

        let data = try makeEncoder().encode(original)
        let decoded = try makeDecoder().decode(ExportData.self, from: data)

        #expect(decoded.dayCategories.count == 2)
        let workday = decoded.dayCategories.first(where: { $0.name == "Workday" })
        #expect(workday?.icon == "briefcase.fill")
    }

    @Test("ExportData preserves export date")
    func testExportDate() throws {
        let date = Date(timeIntervalSince1970: 1710000000) // fixed point
        let original = ExportData(
            routines: [],
            customLocations: [],
            savedLocations: [:],
            dayCategories: [],
            exportDate: date,
            appVersion: "2.0.0"
        )

        let data = try makeEncoder().encode(original)
        let decoded = try makeDecoder().decode(ExportData.self, from: data)

        // ISO 8601 encoding loses sub-second precision
        #expect(abs(decoded.exportDate.timeIntervalSince1970 - date.timeIntervalSince1970) < 1)
        #expect(decoded.appVersion == "2.0.0")
    }

    // MARK: - Edge Cases

    @Test("Empty ExportData round-trips correctly")
    func testEmptyExportData() throws {
        let original = ExportData(
            routines: [],
            customLocations: [],
            savedLocations: [:],
            dayCategories: [],
            exportDate: Date(),
            appVersion: "1.0.0"
        )

        let data = try makeEncoder().encode(original)
        let decoded = try makeDecoder().decode(ExportData.self, from: data)

        #expect(decoded.routines.isEmpty)
        #expect(decoded.customLocations.isEmpty)
        #expect(decoded.savedLocations.isEmpty)
        #expect(decoded.dayCategories.isEmpty)
    }

    @Test("ExportData with context rules round-trips correctly")
    func testExportWithContextRules() throws {
        let template = RoutineTemplate(
            name: "Office Morning",
            habits: [Habit(name: "Task", type: .task(subtasks: []), order: 0)],
            contextRule: RoutineContextRule(
                timeSlots: [.earlyMorning, .morning],
                dayCategoryIds: ["workday"],
                locationIds: ["office"],
                priority: 10
            )
        )

        let original = ExportData(
            routines: [template],
            customLocations: [],
            savedLocations: [:],
            dayCategories: [],
            exportDate: Date(),
            appVersion: "1.0.0"
        )

        let data = try makeEncoder().encode(original)
        let decoded = try makeDecoder().decode(ExportData.self, from: data)

        let decodedRule = decoded.routines[0].contextRule
        #expect(decodedRule != nil)
        #expect(decodedRule?.timeSlots == [.earlyMorning, .morning])
        #expect(decodedRule?.dayCategoryIds == ["workday"])
        #expect(decodedRule?.locationIds == ["office"])
        #expect(decodedRule?.priority == 10)
    }

    @Test("Invalid JSON string throws ImportError")
    func testInvalidJSONImport() throws {
        let decoder = makeDecoder()

        #expect(throws: (any Error).self) {
            _ = try decoder.decode(ExportData.self, from: "not json".data(using: .utf8)!)
        }
    }

    @Test("JSON with unknown location type is skipped gracefully")
    func testUnknownLocationTypeSkipped() throws {
        // Manually construct JSON with an unknown location type
        let json = """
        {
            "routines": [],
            "customLocations": [],
            "savedLocations": [
                {
                    "locationType": "nonexistent_place",
                    "location": {
                        "coordinate": {"latitude": 48.0, "longitude": 16.0},
                        "radius": 100,
                        "dateCreated": "2024-01-01T00:00:00Z"
                    }
                }
            ],
            "dayCategories": [],
            "exportDate": "2024-01-01T00:00:00Z",
            "appVersion": "1.0.0"
        }
        """

        let decoded = try makeDecoder().decode(ExportData.self, from: json.data(using: .utf8)!)

        // Unknown location type should be silently skipped
        #expect(decoded.savedLocations.isEmpty,
               "Unknown location type should be skipped, not crash")
    }

    // MARK: - Import Result

    @Test("ImportResult computed properties are correct")
    func testImportResultComputedProperties() {
        var result = ImportResult()
        result.routinesImported = 3
        result.routinesSkipped = 1
        result.customLocationsImported = 2
        result.customLocationsSkipped = 1
        result.savedLocationsImported = 2
        result.dayCategoriesImported = 1

        #expect(result.totalItemsImported == 8) // 3+2+2+1
        #expect(result.totalItemsSkipped == 2) // 1+1
        #expect(result.hasImportedItems == true)
    }

    @Test("ImportResult with zero imports reports correctly")
    func testEmptyImportResult() {
        let result = ImportResult()

        #expect(result.totalItemsImported == 0)
        #expect(result.totalItemsSkipped == 0)
        #expect(result.hasImportedItems == false)
    }
}
