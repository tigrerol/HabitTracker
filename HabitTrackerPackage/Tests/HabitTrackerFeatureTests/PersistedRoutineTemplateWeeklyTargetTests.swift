import Testing
import Foundation
import SwiftData
@testable import HabitTrackerFeature

@Suite("PersistedRoutineTemplate weeklyTarget round-trip")
struct PersistedRoutineTemplateWeeklyTargetTests {

    @MainActor
    @Test func domainToPersistedToDomainPreservesTarget() throws {
        let container = try DataModelConfiguration.createTestModelContainer()
        let context = ModelContext(container)

        let original = RoutineTemplate(name: "Morning", weeklyTarget: 5)
        let persisted = PersistedRoutineTemplate(from: original)
        context.insert(persisted)
        try context.save()

        let fetchDescriptor = FetchDescriptor<PersistedRoutineTemplate>()
        let results = try context.fetch(fetchDescriptor)
        let fetched = try #require(results.first)
        #expect(fetched.toDomainModel().weeklyTarget == 5)
    }

    @MainActor
    @Test func updatePropagatesTargetChange() throws {
        let container = try DataModelConfiguration.createTestModelContainer()
        let context = ModelContext(container)

        var template = RoutineTemplate(name: "Morning", weeklyTarget: 3)
        let persisted = PersistedRoutineTemplate(from: template)
        context.insert(persisted)
        try context.save()

        template.weeklyTarget = 7
        persisted.update(from: template)

        #expect(persisted.toDomainModel().weeklyTarget == 7)
    }

    @MainActor
    @Test func nilTargetPersists() throws {
        let container = try DataModelConfiguration.createTestModelContainer()
        let context = ModelContext(container)

        let original = RoutineTemplate(name: "Morning")
        let persisted = PersistedRoutineTemplate(from: original)
        context.insert(persisted)
        try context.save()

        #expect(persisted.toDomainModel().weeklyTarget == nil)
    }
}
