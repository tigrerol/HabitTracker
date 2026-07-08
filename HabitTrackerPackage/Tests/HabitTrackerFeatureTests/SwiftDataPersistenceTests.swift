import Testing
import Foundation
import SwiftData
@testable import HabitTrackerFeature

@Suite("SwiftData Persistence Round-Trip Tests", .serialized)
struct SwiftDataPersistenceTests {

    // MARK: - Helper

    /// Bundles the container with the service: ModelContext does NOT retain
    /// its ModelContainer, so returning only the service would let the
    /// container deallocate — and the next fetch crashes (EXC_BREAKPOINT).
    private struct TestStore {
        let container: ModelContainer
        let service: SwiftDataPersistenceService
    }

    @MainActor
    private func createTestService() throws -> TestStore {
        let container = try DataModelConfiguration.createTestModelContainer()
        return TestStore(
            container: container,
            service: SwiftDataPersistenceService(modelContext: container.mainContext)
        )
    }

    // MARK: - PersistedHabit Round-Trip

    @Test("Habit survives PersistedHabit round-trip for all types")
    @MainActor func testHabitRoundTrip() throws {
        let types: [HabitType] = [
            .task(subtasks: []),
            .task(subtasks: [Subtask(name: "Sub A"), Subtask(name: "Sub B", isOptional: true)]),
            .timer(style: .down, duration: 300),
            .timer(style: .up, duration: 0, target: 600),
            .timer(style: .multiple, duration: 0, steps: [
                SequenceStep(name: "Work", duration: 30),
                SequenceStep(name: "Rest", duration: 10)
            ], repeatCount: 3),
            .action(type: .app, identifier: "com.apple.Health", displayName: "Health", estimatedDuration: 120),
            .action(type: .website, identifier: "https://example.com", displayName: "Example"),
            .action(type: .shortcut, identifier: "my-shortcut", displayName: "Shortcut"),
            .tracking(.counter(items: ["A", "B", "C"])),
            .tracking(.measurement(unit: "bpm", targetValue: 65.0)),
            .tracking(.measurement(unit: "kg", targetValue: nil)),
            .guidedSequence(steps: [
                SequenceStep(name: "Warm up", duration: 60),
                SequenceStep(name: "Main", duration: 120, instructions: "Focus on breathing")
            ]),
            .conditional(ConditionalHabitInfo(
                question: "Energy level?",
                options: [
                    ConditionalOption(text: "High", habits: [Habit(name: "Hard workout", type: .timer(style: .down, duration: 600))]),
                    ConditionalOption(text: "Low", habits: [Habit(name: "Easy stretch", type: .timer(style: .down, duration: 300))])
                ]
            ))
        ]

        for habitType in types {
            let original = Habit(
                name: "Test \(habitType.description)",
                type: habitType,
                isOptional: true,
                notes: "Test notes",
                color: "#FF5733",
                order: 42,
                isActive: true
            )

            let persisted = PersistedHabit(from: original)
            let restored = persisted.toDomainModel()

            #expect(restored.id == original.id, "ID mismatch for \(habitType.description)")
            #expect(restored.name == original.name, "Name mismatch for \(habitType.description)")
            #expect(restored.type == original.type, "Type mismatch for \(habitType.description)")
            #expect(restored.isOptional == original.isOptional, "isOptional mismatch for \(habitType.description)")
            #expect(restored.notes == original.notes, "Notes mismatch for \(habitType.description)")
            #expect(restored.color == original.color, "Color mismatch for \(habitType.description)")
            #expect(restored.order == original.order, "Order mismatch for \(habitType.description)")
            #expect(restored.isActive == original.isActive, "isActive mismatch for \(habitType.description)")
        }
    }

    // MARK: - PersistedRoutineTemplate Round-Trip

    @Test("RoutineTemplate survives PersistedRoutineTemplate round-trip")
    @MainActor func testRoutineTemplateRoundTrip() throws {
        let habits = [
            Habit(name: "Task", type: .task(subtasks: []), order: 0),
            Habit(name: "Timer", type: .timer(style: .down, duration: 300), order: 1),
            Habit(name: "Counter", type: .tracking(.counter(items: ["A", "B"])), order: 2)
        ]

        let original = RoutineTemplate(
            name: "Morning Office",
            description: "Office routine",
            habits: habits,
            color: "#34C759",
            isDefault: true,
            contextRule: RoutineContextRule(
                timeSlots: [.earlyMorning, .morning],
                dayCategoryIds: ["workday"],
                locationIds: ["office"],
                priority: 5
            )
        )

        let persisted = PersistedRoutineTemplate(from: original)

        // Manually set up habits relationship (normally done by SwiftData)
        for habit in habits {
            let persistedHabit = PersistedHabit(from: habit)
            persistedHabit.template = persisted
            persisted.habits.append(persistedHabit)
        }

        let restored = persisted.toDomainModel()

        #expect(restored.id == original.id)
        #expect(restored.name == original.name)
        #expect(restored.description == original.description)
        #expect(restored.color == original.color)
        #expect(restored.isDefault == original.isDefault)
        #expect(restored.habits.count == original.habits.count)
        #expect(restored.contextRule == original.contextRule)

        // Verify habits are restored in order
        let sortedRestored = restored.habits.sorted { $0.order < $1.order }
        let sortedOriginal = original.habits.sorted { $0.order < $1.order }
        for (r, o) in zip(sortedRestored, sortedOriginal) {
            #expect(r.name == o.name)
            #expect(r.type == o.type)
            #expect(r.order == o.order)
        }
    }

    // MARK: - PersistedMoodRating Round-Trip

    @Test("MoodRating survives PersistedMoodRating round-trip for all moods")
    @MainActor func testMoodRatingRoundTrip() throws {
        for mood in Mood.allCases {
            let original = MoodRating(
                sessionId: UUID(),
                rating: mood,
                notes: "Feeling \(mood.description)"
            )

            let persisted = PersistedMoodRating(from: original)
            let restored = persisted.toDomainModel()

            #expect(restored != nil, "Should decode \(mood.rawValue) successfully")
            #expect(restored?.id == original.id)
            #expect(restored?.sessionId == original.sessionId)
            #expect(restored?.rating == original.rating)
            #expect(restored?.notes == original.notes)
        }
    }

    @Test("MoodRating with nil notes round-trips correctly")
    @MainActor func testMoodRatingNilNotes() throws {
        let original = MoodRating(sessionId: UUID(), rating: .good)
        let persisted = PersistedMoodRating(from: original)
        let restored = persisted.toDomainModel()

        #expect(restored?.notes == nil)
    }

    // MARK: - PersistedHabitCompletion Round-Trip

    @Test("HabitCompletion survives round-trip")
    @MainActor func testHabitCompletionRoundTrip() throws {
        let original = HabitCompletion(
            habitId: UUID(),
            completedAt: Date(),
            duration: 125.5,
            isSkipped: false,
            notes: "Done quickly"
        )

        let persisted = PersistedHabitCompletion(from: original)
        let restored = persisted.toDomainModel()

        #expect(restored.id == original.id)
        #expect(restored.habitId == original.habitId)
        #expect(restored.duration == original.duration)
        #expect(restored.isSkipped == original.isSkipped)
        #expect(restored.notes == original.notes)
    }

    @Test("Skipped HabitCompletion round-trips correctly")
    @MainActor func testSkippedCompletionRoundTrip() throws {
        let original = HabitCompletion(
            habitId: UUID(),
            completedAt: Date(),
            isSkipped: true
        )

        let persisted = PersistedHabitCompletion(from: original)
        let restored = persisted.toDomainModel()

        #expect(restored.isSkipped == true)
        #expect(restored.duration == nil)
        #expect(restored.notes == nil)
    }

    // MARK: - PersistedCustomLocation Round-Trip

    @Test("CustomLocation with coordinates survives round-trip")
    @MainActor func testCustomLocationWithCoordinatesRoundTrip() throws {
        let original = CustomLocation(
            name: "My Gym",
            icon: "dumbbell.fill",
            coordinate: LocationCoordinate(latitude: 48.2082, longitude: 16.3738),
            radius: 200
        )

        let persisted = PersistedCustomLocation(from: original)
        let restored = persisted.toDomainModel()

        #expect(restored.id == original.id)
        #expect(restored.name == original.name)
        #expect(restored.icon == original.icon)
        #expect(restored.radius == original.radius)
        #expect(restored.coordinate?.latitude == original.coordinate?.latitude)
        #expect(restored.coordinate?.longitude == original.coordinate?.longitude)
    }

    @Test("CustomLocation without coordinates survives round-trip")
    @MainActor func testCustomLocationNoCoordinatesRoundTrip() throws {
        let original = CustomLocation(
            name: "Anywhere",
            icon: "location.fill",
            coordinate: nil
        )

        let persisted = PersistedCustomLocation(from: original)
        let restored = persisted.toDomainModel()

        #expect(restored.id == original.id)
        #expect(restored.name == original.name)
        #expect(restored.coordinate == nil)
    }

    // MARK: - SwiftDataPersistenceService Integration

    @Test("Save and load routine templates via persistence service")
    @MainActor func testSaveLoadTemplates() async throws {
        let store = try createTestService(); let service = store.service

        let templates = [
            RoutineTemplate(
                name: "Morning",
                habits: [
                    Habit(name: "Meditate", type: .timer(style: .down, duration: 600), order: 0),
                    Habit(name: "Exercise", type: .task(subtasks: []), order: 1)
                ]
            ),
            RoutineTemplate(
                name: "Evening",
                habits: [
                    Habit(name: "Journal", type: .task(subtasks: []), order: 0)
                ]
            )
        ]

        try await service.save(templates, forKey: PersistenceKeys.routineTemplates)

        let loaded: [RoutineTemplate]? = try await service.load([RoutineTemplate].self, forKey: PersistenceKeys.routineTemplates)

        #expect(loaded != nil)
        #expect(loaded?.count == 2)

        let morningTemplate = loaded?.first(where: { $0.name == "Morning" })
        #expect(morningTemplate != nil)
        #expect(morningTemplate?.habits.count == 2)

        let eveningTemplate = loaded?.first(where: { $0.name == "Evening" })
        #expect(eveningTemplate != nil)
        #expect(eveningTemplate?.habits.count == 1)
    }

    @Test("Save templates twice performs upsert, not duplication")
    @MainActor func testUpsertTemplates() async throws {
        let store = try createTestService(); let service = store.service
        let templateId = UUID()

        // Save initial
        let templates1 = [
            RoutineTemplate(id: templateId, name: "Morning", habits: [
                Habit(name: "Task 1", type: .task(subtasks: []), order: 0)
            ])
        ]
        try await service.save(templates1, forKey: PersistenceKeys.routineTemplates)

        // Save updated
        let templates2 = [
            RoutineTemplate(id: templateId, name: "Morning Updated", habits: [
                Habit(name: "Task 1", type: .task(subtasks: []), order: 0),
                Habit(name: "Task 2", type: .task(subtasks: []), order: 1)
            ])
        ]
        try await service.save(templates2, forKey: PersistenceKeys.routineTemplates)

        let loaded: [RoutineTemplate]? = try await service.load([RoutineTemplate].self, forKey: PersistenceKeys.routineTemplates)

        #expect(loaded?.count == 1, "Should update, not duplicate")
        #expect(loaded?.first?.name == "Morning Updated")
        #expect(loaded?.first?.habits.count == 2)
    }

    @Test("Deleting a template removes it from persistence")
    @MainActor func testDeleteTemplate() async throws {
        let store = try createTestService(); let service = store.service

        let templates = [
            RoutineTemplate(name: "Keep"),
            RoutineTemplate(name: "Remove")
        ]
        try await service.save(templates, forKey: PersistenceKeys.routineTemplates)

        // Save only the one to keep
        let keepTemplates = templates.filter { $0.name == "Keep" }
        try await service.save(keepTemplates, forKey: PersistenceKeys.routineTemplates)

        let loaded: [RoutineTemplate]? = try await service.load([RoutineTemplate].self, forKey: PersistenceKeys.routineTemplates)

        #expect(loaded?.count == 1)
        #expect(loaded?.first?.name == "Keep")
    }

    @Test("Save and load mood ratings")
    @MainActor func testSaveLoadMoodRatings() async throws {
        let store = try createTestService(); let service = store.service

        let ratings = [
            MoodRating(sessionId: UUID(), rating: .excellent, notes: "Great morning"),
            MoodRating(sessionId: UUID(), rating: .good),
            MoodRating(sessionId: UUID(), rating: .neutral, notes: "Meh")
        ]

        try service.saveMoodRatings(ratings)
        let loaded = await service.loadMoodRatings()

        #expect(loaded.count == 3)

        let excellent = loaded.first(where: { $0.rating == .excellent })
        #expect(excellent?.notes == "Great morning")
    }

    @Test("Mood ratings overwrite preserves correct count")
    @MainActor func testMoodRatingsOverwrite() async throws {
        let store = try createTestService(); let service = store.service

        // Save 3 ratings
        let ratings1 = [
            MoodRating(sessionId: UUID(), rating: .good),
            MoodRating(sessionId: UUID(), rating: .bad),
            MoodRating(sessionId: UUID(), rating: .neutral)
        ]
        try service.saveMoodRatings(ratings1)

        // Save 2 different ratings (overwrites all)
        let ratings2 = [
            MoodRating(sessionId: UUID(), rating: .excellent),
            MoodRating(sessionId: UUID(), rating: .terrible)
        ]
        try service.saveMoodRatings(ratings2)

        let loaded = await service.loadMoodRatings()
        #expect(loaded.count == 2, "Should replace all previous ratings")
    }

    @Test("Empty load returns nil or empty array")
    @MainActor func testEmptyLoad() async throws {
        let store = try createTestService(); let service = store.service

        let templates: [RoutineTemplate]? = try await service.load([RoutineTemplate].self, forKey: PersistenceKeys.routineTemplates)
        #expect(templates?.isEmpty == true || templates == nil)
    }

    @Test("Exists returns false for empty store, true after save")
    @MainActor func testExists() async throws {
        let store = try createTestService(); let service = store.service

        let existsBefore = await service.exists(forKey: PersistenceKeys.routineTemplates)
        #expect(!existsBefore)

        let templates = [RoutineTemplate(name: "Test")]
        try await service.save(templates, forKey: PersistenceKeys.routineTemplates)

        let existsAfter = await service.exists(forKey: PersistenceKeys.routineTemplates)
        #expect(existsAfter)
    }

    // MARK: - Legacy UserDefaults Migration

    @MainActor
    private func createMigratingService(defaults: UserDefaults) throws -> TestStore {
        let container = try DataModelConfiguration.createTestModelContainer()
        return TestStore(
            container: container,
            service: SwiftDataPersistenceService(
                modelContext: container.mainContext,
                migratesLegacyUserDefaults: true,
                userDefaults: defaults
            )
        )
    }

    @Test("Legacy templates and session history migrate on first load, exactly once")
    @MainActor func testLegacyMigration() async throws {
        let suiteName = "test-migration-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        // Seed the legacy store: one template with a habit, plus a completed session
        let legacy = UserDefaultsPersistenceService(userDefaults: defaults)
        let habit = Habit(name: "Old habit", type: .task(subtasks: []), order: 0)
        let template = RoutineTemplate(name: "Legacy", habits: [habit])
        try await legacy.save([template], forKey: PersistenceKeys.routineTemplates)

        let session = RoutineSessionData(
            id: UUID(),
            startedAt: Date().addingTimeInterval(-3600),
            completedAt: Date(),
            currentHabitIndex: 1,
            completions: [HabitCompletion(habitId: habit.id, completedAt: Date())],
            modifications: []
        )
        await legacy.saveRoutineSession(session, for: template.id)

        // First load through a migrating service imports templates and history
        let store = try createMigratingService(defaults: defaults); let service = store.service
        let loaded: [RoutineTemplate]? = try await service.load([RoutineTemplate].self, forKey: PersistenceKeys.routineTemplates)

        #expect(loaded?.count == 1)
        #expect(loaded?.first?.name == "Legacy")
        #expect(loaded?.first?.habits.count == 1)

        let sessions = await service.loadRoutineSessions(for: template.id)
        #expect(sessions.count == 1)
        #expect(sessions.first?.id == session.id)
        #expect(sessions.first?.completions.count == 1)

        // Migration is one-shot: deleting everything must not resurrect legacy data
        try await service.save([RoutineTemplate](), forKey: PersistenceKeys.routineTemplates)
        let afterDeletion: [RoutineTemplate]? = try await service.load([RoutineTemplate].self, forKey: PersistenceKeys.routineTemplates)
        #expect(afterDeletion?.isEmpty == true)
    }

    @Test("Fresh install (nothing to migrate) loads nil so samples get created")
    @MainActor func testFreshInstallLoadsNil() async throws {
        let suiteName = "test-fresh-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = try createMigratingService(defaults: defaults); let service = store.service

        let first: [RoutineTemplate]? = try await service.load([RoutineTemplate].self, forKey: PersistenceKeys.routineTemplates)
        #expect(first == nil)

        // After the first save, an emptied store is a deliberate state → []
        try await service.save([RoutineTemplate(name: "Mine")], forKey: PersistenceKeys.routineTemplates)
        try await service.save([RoutineTemplate](), forKey: PersistenceKeys.routineTemplates)
        let emptied: [RoutineTemplate]? = try await service.load([RoutineTemplate].self, forKey: PersistenceKeys.routineTemplates)
        #expect(emptied?.isEmpty == true)
    }

    @Test("Non-template keys round-trip through the injected UserDefaults")
    @MainActor func testFallbackKeysUseInjectedDefaults() async throws {
        let suiteName = "test-fallback-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let container = try DataModelConfiguration.createTestModelContainer()
        let service = SwiftDataPersistenceService(modelContext: container.mainContext, userDefaults: defaults)

        try await service.save(["a", "b"], forKey: "SomeSettingsKey")
        let loaded: [String]? = try await service.load([String].self, forKey: "SomeSettingsKey")
        #expect(loaded == ["a", "b"])
        #expect(UserDefaults.standard.data(forKey: "SomeSettingsKey") == nil)
    }
}
