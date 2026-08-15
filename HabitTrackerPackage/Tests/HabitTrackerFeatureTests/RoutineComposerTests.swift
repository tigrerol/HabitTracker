import Testing
import Foundation
@testable import HabitTrackerFeature

@Suite("Routine composition")
@MainActor
struct RoutineComposerTests {

    private func habit(_ name: String, order: Int, isActive: Bool = true) -> Habit {
        Habit(name: name, type: .task(subtasks: []), order: order, isActive: isActive)
    }

    @Test("A routine without includes is returned untouched")
    func plainRoutineUnchanged() {
        let template = RoutineTemplate(name: "Morning", habits: [habit("Water", order: 0)])
        let resolved = RoutineComposer.resolve(template, in: [template])

        #expect(resolved.habits.map(\.name) == ["Water"])
        #expect(resolved.habits.allSatisfy { $0.blockName == nil })
        #expect(resolved.id == template.id)
    }

    @Test("An included routine's habits are spliced in at the block's position")
    func includeSplicedByOrder() {
        let core = RoutineTemplate(
            name: "Core Morning",
            habits: [habit("Water", order: 0), habit("Weigh in", order: 1)]
        )
        let wrapper = RoutineTemplate(
            name: "Morning Vacation",
            habits: [habit("Sunscreen", order: 0), habit("Read", order: 2)],
            includes: [RoutineInclude(templateId: core.id, order: 1)]
        )

        let resolved = RoutineComposer.resolve(wrapper, in: [core, wrapper])

        #expect(resolved.habits.map(\.name) == ["Sunscreen", "Water", "Weigh in", "Read"])
        #expect(resolved.habits.map(\.order) == [0, 1, 2, 3])
    }

    @Test("Habits carry the name of the block they came from")
    func blockNamesAssigned() {
        let core = RoutineTemplate(name: "Core Morning", habits: [habit("Water", order: 0)])
        let wrapper = RoutineTemplate(
            name: "Morning Vacation",
            habits: [habit("Read", order: 1)],
            includes: [RoutineInclude(templateId: core.id, order: 0)]
        )

        let resolved = RoutineComposer.resolve(wrapper, in: [core, wrapper])

        #expect(resolved.habits.map(\.blockName) == ["Core Morning", "Morning Vacation"])
    }

    @Test("Composition is one level deep — a nested include is not expanded")
    func nestedIncludeNotExpanded() {
        let inner = RoutineTemplate(name: "Inner", habits: [habit("Deep", order: 0)])
        let middle = RoutineTemplate(
            name: "Middle",
            habits: [habit("Mid", order: 1)],
            includes: [RoutineInclude(templateId: inner.id, order: 0)]
        )
        let outer = RoutineTemplate(
            name: "Outer",
            habits: [],
            includes: [RoutineInclude(templateId: middle.id, order: 0)]
        )

        let resolved = RoutineComposer.resolve(outer, in: [inner, middle, outer])

        #expect(resolved.habits.map(\.name) == ["Mid"])
    }

    @Test("Inactive habits inside a block are left out")
    func inactiveBlockHabitsSkipped() {
        let core = RoutineTemplate(
            name: "Core",
            habits: [habit("On", order: 0), habit("Off", order: 1, isActive: false)]
        )
        let wrapper = RoutineTemplate(name: "Wrapper", includes: [RoutineInclude(templateId: core.id, order: 0)])

        let resolved = RoutineComposer.resolve(wrapper, in: [core, wrapper])

        #expect(resolved.habits.map(\.name) == ["On"])
    }

    @Test("An include pointing at a deleted routine is skipped, not fatal")
    func missingIncludeSkipped() {
        let wrapper = RoutineTemplate(
            name: "Wrapper",
            habits: [habit("Own", order: 1)],
            includes: [RoutineInclude(templateId: UUID(), order: 0)]
        )

        let resolved = RoutineComposer.resolve(wrapper, in: [wrapper])

        #expect(resolved.habits.map(\.name) == ["Own"])
    }

    @Test("Inactive includes are skipped")
    func inactiveIncludeSkipped() {
        let core = RoutineTemplate(name: "Core", habits: [habit("Water", order: 0)])
        let wrapper = RoutineTemplate(
            name: "Wrapper",
            habits: [habit("Own", order: 1)],
            includes: [RoutineInclude(templateId: core.id, order: 0, isActive: false)]
        )

        let resolved = RoutineComposer.resolve(wrapper, in: [core, wrapper])

        #expect(resolved.habits.map(\.name) == ["Own"])
    }

    @Test("Self-inclusion is ignored")
    func selfIncludeIgnored() {
        let id = UUID()
        let wrapper = RoutineTemplate(
            id: id,
            name: "Wrapper",
            habits: [habit("Own", order: 1)],
            includes: [RoutineInclude(templateId: id, order: 0)]
        )

        let resolved = RoutineComposer.resolve(wrapper, in: [wrapper])

        #expect(resolved.habits.map(\.name) == ["Own"])
    }

    @Test("Including the same routine twice yields no duplicate habits")
    func duplicateIncludeDeduped() {
        let core = RoutineTemplate(name: "Core", habits: [habit("Water", order: 0)])
        let wrapper = RoutineTemplate(
            name: "Wrapper",
            includes: [
                RoutineInclude(templateId: core.id, order: 0),
                RoutineInclude(templateId: core.id, order: 1)
            ]
        )

        let resolved = RoutineComposer.resolve(wrapper, in: [core, wrapper])

        #expect(resolved.habits.map(\.name) == ["Water"])
    }

    @Test("The resolved copy carries no includes and keeps the wrapper's identity")
    func resolvedCopyIsInert() {
        let core = RoutineTemplate(name: "Core", habits: [habit("Water", order: 0)])
        let rule = RoutineContextRule(timeSlots: [.morning], priority: 2)
        let wrapper = RoutineTemplate(
            name: "Wrapper",
            contextRule: rule,
            includes: [RoutineInclude(templateId: core.id, order: 0)]
        )

        let resolved = RoutineComposer.resolve(wrapper, in: [core, wrapper])

        #expect(resolved.includes.isEmpty)
        #expect(resolved.id == wrapper.id)
        #expect(resolved.contextRule == rule)
    }

    @Test("canInclude blocks self, duplicates, and wrappers")
    func canIncludeRules() {
        let core = RoutineTemplate(name: "Core", habits: [habit("Water", order: 0)])
        let otherWrapper = RoutineTemplate(name: "Other", includes: [RoutineInclude(templateId: core.id)])
        let wrapper = RoutineTemplate(name: "Wrapper", includes: [RoutineInclude(templateId: core.id)])

        #expect(RoutineComposer.canInclude(core, into: wrapper) == false)      // already included
        #expect(RoutineComposer.canInclude(wrapper, into: wrapper) == false)   // itself
        #expect(RoutineComposer.canInclude(otherWrapper, into: wrapper) == false) // is a wrapper
        #expect(RoutineComposer.canInclude(RoutineTemplate(name: "Fresh"), into: wrapper))
    }

    @Test("templatesIncluding finds every wrapper using a routine")
    func findsWrappers() {
        let core = RoutineTemplate(name: "Core")
        let a = RoutineTemplate(name: "A", includes: [RoutineInclude(templateId: core.id)])
        let b = RoutineTemplate(name: "B", includes: [RoutineInclude(templateId: core.id)])
        let c = RoutineTemplate(name: "C")

        let found = RoutineComposer.templatesIncluding(core.id, in: [core, a, b, c])

        #expect(Set(found.map(\.name)) == ["A", "B"])
    }

    @Test("Templates encoded before includes existed still decode")
    func legacyTemplateDecodes() throws {
        let legacyJSON = """
        {
          "id": "\(UUID().uuidString)",
          "name": "Legacy",
          "habits": [],
          "color": "#34C759",
          "isDefault": false,
          "createdAt": 760000000
        }
        """
        let decoded = try JSONDecoder().decode(RoutineTemplate.self, from: Data(legacyJSON.utf8))

        #expect(decoded.name == "Legacy")
        #expect(decoded.includes.isEmpty)
    }

    @Test("A template with includes survives a Codable round trip")
    func includesRoundTrip() throws {
        let include = RoutineInclude(templateId: UUID(), order: 3)
        let template = RoutineTemplate(name: "Wrapper", includes: [include])

        let data = try JSONEncoder().encode(template)
        let decoded = try JSONDecoder().decode(RoutineTemplate.self, from: data)

        #expect(decoded.includes == [include])
    }
}

@Suite("Sessions from composed routines")
@MainActor
struct ComposedSessionTests {

    private func makeService(_ label: String) throws -> RoutineService {
        let defaults = try makeIsolatedDefaults(label)
        let modeDefaults = try makeIsolatedDefaults("\(label)-modes")
        return RoutineService(
            persistenceService: UserDefaultsPersistenceService(userDefaults: defaults),
            modeService: RoutineModeService(persistenceService: UserDefaultsPersistenceService(userDefaults: modeDefaults))
        )
    }

    @Test("Starting a wrapper runs the expanded habit list")
    func sessionUsesResolvedHabits() async throws {
        let service = try makeService("composed-session")
        await service.ensureLoaded()

        let core = RoutineTemplate(
            name: "Core Morning",
            habits: [Habit(name: "Water", type: .task(subtasks: []), order: 0)]
        )
        service.addTemplate(core)

        let wrapper = RoutineTemplate(
            name: "Morning Vacation",
            habits: [Habit(name: "Read", type: .task(subtasks: []), order: 1)],
            includes: [RoutineInclude(templateId: core.id, order: 0)]
        )
        service.addTemplate(wrapper)

        try service.startSession(with: wrapper)

        let session = try #require(service.currentSession)
        #expect(session.activeHabits.map(\.name) == ["Water", "Read"])
        #expect(session.activeHabits.map(\.blockName) == ["Core Morning", "Morning Vacation"])
        #expect(session.template.id == wrapper.id)
    }

    @Test("A wrapper with no habits of its own still starts")
    func wrapperWithOnlyBlocksStarts() async throws {
        let service = try makeService("composed-empty-wrapper")
        await service.ensureLoaded()

        let core = RoutineTemplate(
            name: "Core",
            habits: [Habit(name: "Water", type: .task(subtasks: []), order: 0)]
        )
        service.addTemplate(core)

        let wrapper = RoutineTemplate(name: "Wrapper", includes: [RoutineInclude(templateId: core.id, order: 0)])
        service.addTemplate(wrapper)

        try service.startSession(with: wrapper)
        #expect(service.currentSession?.activeHabits.count == 1)
    }

    @Test("Deleting a routine strips it from wrappers that include it")
    func deletePrunesIncludes() async throws {
        let service = try makeService("composed-delete")
        await service.ensureLoaded()

        let core = RoutineTemplate(
            name: "Core",
            habits: [Habit(name: "Water", type: .task(subtasks: []), order: 0)]
        )
        service.addTemplate(core)

        let wrapper = RoutineTemplate(
            name: "Wrapper",
            habits: [Habit(name: "Own", type: .task(subtasks: []), order: 1)],
            includes: [RoutineInclude(templateId: core.id, order: 0)]
        )
        service.addTemplate(wrapper)

        #expect(service.templatesIncluding(core.id).map(\.name) == ["Wrapper"])

        service.deleteTemplate(withId: core.id)

        let stored = try #require(service.templates.first { $0.id == wrapper.id })
        #expect(stored.includes.isEmpty)
    }

    @Test("Export flattens wrapper routines so files stay self-contained")
    func exportResolvesIncludes() async throws {
        let service = try makeService("composed-export")
        await service.ensureLoaded()

        let core = RoutineTemplate(
            name: "Core",
            habits: [Habit(name: "Water", type: .task(subtasks: []), order: 0)]
        )
        service.addTemplate(core)

        let wrapper = RoutineTemplate(
            name: "Wrapper",
            habits: [Habit(name: "Own", type: .task(subtasks: []), order: 1)],
            includes: [RoutineInclude(templateId: core.id, order: 0)]
        )
        service.addTemplate(wrapper)

        let exported = DataExportService(routineService: service).exportData()
        let exportedWrapper = try #require(exported.routines.first { $0.id == wrapper.id })

        #expect(exportedWrapper.includes.isEmpty)
        #expect(exportedWrapper.habits.map(\.name) == ["Water", "Own"])
    }
}
