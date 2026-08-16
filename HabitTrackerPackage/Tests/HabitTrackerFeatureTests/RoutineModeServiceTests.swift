import Testing
import Foundation
@testable import HabitTrackerFeature

@Suite("Routine modes")
@MainActor
struct RoutineModeServiceTests {

    private func makeService(_ label: String = "modes") throws -> (RoutineModeService, UserDefaults) {
        let defaults = try makeIsolatedDefaults(label)
        let service = RoutineModeService(persistenceService: UserDefaultsPersistenceService(userDefaults: defaults))
        return (service, defaults)
    }

    private func templates(_ count: Int) -> [RoutineTemplate] {
        (0..<count).map { RoutineTemplate(name: "Routine \($0)") }
    }

    @Test("No active mode shows every routine")
    func noActiveModeShowsAll() async throws {
        let (service, _) = try makeService()
        await service.ensureLoaded()
        let all = templates(4)

        #expect(service.activeMode == nil)
        #expect(service.visibleTemplates(from: all).count == 4)
        #expect(service.isFiltering(all) == false)
    }

    @Test("Active mode hides routines outside it, order preserved")
    func activeModeFilters() async throws {
        let (service, _) = try makeService()
        await service.ensureLoaded()
        let all = templates(4)

        let mode = RoutineMode(name: "Vacation", templateIds: [all[0].id, all[2].id])
        service.addMode(mode)
        service.activate(modeId: mode.id)

        let visible = service.visibleTemplates(from: all)
        #expect(visible.map(\.id) == [all[0].id, all[2].id])
        #expect(service.isFiltering(all))
    }

    @Test("Empty mode fails open rather than emptying the Today tab")
    func emptyModeFailsOpen() async throws {
        let (service, _) = try makeService()
        await service.ensureLoaded()
        let all = templates(3)

        let mode = RoutineMode(name: "Vacation")
        service.addMode(mode)
        service.activate(modeId: mode.id)

        #expect(service.visibleTemplates(from: all).count == 3)
        #expect(service.isFiltering(all) == false)
    }

    @Test("A mode whose routines were all deleted fails open")
    func staleMembershipFailsOpen() async throws {
        let (service, _) = try makeService()
        await service.ensureLoaded()
        let all = templates(2)

        let mode = RoutineMode(name: "Travel", templateIds: [UUID(), UUID()])
        service.addMode(mode)
        service.activate(modeId: mode.id)

        #expect(service.visibleTemplates(from: all).count == 2)
    }

    @Test("Deactivating restores the full list")
    func deactivateRestoresAll() async throws {
        let (service, _) = try makeService()
        await service.ensureLoaded()
        let all = templates(3)

        let mode = RoutineMode(name: "Sick Day", templateIds: [all[1].id])
        service.addMode(mode)
        service.activate(modeId: mode.id)
        #expect(service.visibleTemplates(from: all).count == 1)

        service.deactivate()
        #expect(service.activeMode == nil)
        #expect(service.visibleTemplates(from: all).count == 3)
    }

    @Test("Deleting the active mode clears activation")
    func deletingActiveModeClearsActivation() async throws {
        let (service, _) = try makeService()
        await service.ensureLoaded()

        let mode = RoutineMode(name: "Vacation", templateIds: [UUID()])
        service.addMode(mode)
        service.activate(modeId: mode.id)

        service.deleteMode(withId: mode.id)
        #expect(service.modes.isEmpty)
        #expect(service.activeModeId == nil)
    }

    @Test("Deleting a routine drops it from every mode")
    func deletingRoutinePrunesMembership() async throws {
        let (service, _) = try makeService()
        await service.ensureLoaded()
        let all = templates(2)

        let a = RoutineMode(name: "Vacation", templateIds: [all[0].id, all[1].id])
        let b = RoutineMode(name: "Travel", templateIds: [all[0].id])
        service.addMode(a)
        service.addMode(b)

        service.removeTemplateFromAllModes(all[0].id)

        #expect(service.modes[0].templateIds == [all[1].id])
        #expect(service.modes[1].templateIds.isEmpty)
    }

    @Test("Activating an unknown mode is ignored")
    func activatingUnknownModeIgnored() async throws {
        let (service, _) = try makeService()
        await service.ensureLoaded()

        service.activate(modeId: UUID())
        #expect(service.activeModeId == nil)
    }

    @Test("Modes and activation survive a reload")
    func persistenceRoundTrip() async throws {
        let (service, defaults) = try makeService()
        await service.ensureLoaded()
        let templateId = UUID()

        let mode = RoutineMode(name: "Vacation", icon: "airplane", templateIds: [templateId])
        service.addMode(mode)
        service.activate(modeId: mode.id)

        await service.ensurePersisted()

        let reloaded = RoutineModeService(persistenceService: UserDefaultsPersistenceService(userDefaults: defaults))
        await reloaded.ensureLoaded()

        #expect(reloaded.modes.count == 1)
        #expect(reloaded.modes.first?.name == "Vacation")
        #expect(reloaded.modes.first?.icon == "airplane")
        #expect(reloaded.modes.first?.templateIds == [templateId])
        #expect(reloaded.activeMode?.id == mode.id)
    }

    @Test("A stale active id from persistence is dropped")
    func staleActiveIdDropped() async throws {
        let defaults = try makeIsolatedDefaults("stale-mode")
        let persistence = UserDefaultsPersistenceService(userDefaults: defaults)
        let settings = RoutineModeSettings(modes: [], activeModeId: UUID())
        try await persistence.save(settings, forKey: PersistenceKeys.routineModes)

        let service = RoutineModeService(persistenceService: persistence)
        await service.ensureLoaded()

        #expect(service.activeModeId == nil)
    }

    @Test("Membership count only counts routines that still exist")
    func templateCountIgnoresDeleted() async throws {
        let (service, _) = try makeService()
        await service.ensureLoaded()
        let all = templates(2)

        let mode = RoutineMode(name: "Vacation", templateIds: [all[0].id, UUID()])
        #expect(service.templateCount(for: mode, in: all) == 1)
    }

    @Test("Smart selection stays inside the active mode")
    func smartSelectionRespectsMode() async throws {
        let (modeService, _) = try makeService("smart-mode")
        await modeService.ensureLoaded()

        let defaults = try makeIsolatedDefaults("smart-mode-templates")
        let routineService = RoutineService(
            persistenceService: UserDefaultsPersistenceService(userDefaults: defaults),
            modeService: modeService
        )
        await routineService.ensureLoaded()

        let all = routineService.templates
        try #require(all.count > 1)

        let mode = RoutineMode(name: "Vacation", templateIds: [all[0].id])
        modeService.addMode(mode)
        modeService.activate(modeId: mode.id)

        let result = await routineService.getSmartTemplateAndSort()
        #expect(result.sorted.map(\.id) == [all[0].id])
        #expect(result.best?.id == all[0].id)
    }

    @Test("A routine built during a mode joins that mode")
    func newTemplateJoinsActiveMode() async throws {
        let (service, _) = try makeService()
        await service.ensureLoaded()
        let existing = templates(2)

        let mode = RoutineMode(name: "Vacation", templateIds: [existing[0].id])
        service.addMode(mode)
        service.activate(modeId: mode.id)

        let new = RoutineTemplate(name: "Beach Stretch")
        service.addTemplateToActiveMode(new.id, existing: existing)

        #expect(service.modes[0].templateIds == [existing[0].id, new.id])
        #expect(service.visibleTemplates(from: existing + [new]).map(\.id) == [existing[0].id, new.id])
    }

    @Test("No active mode leaves membership untouched")
    func newTemplateWithoutActiveModeChangesNothing() async throws {
        let (service, _) = try makeService()
        await service.ensureLoaded()
        let existing = templates(2)

        let mode = RoutineMode(name: "Vacation", templateIds: [existing[0].id])
        service.addMode(mode)

        service.addTemplateToActiveMode(UUID(), existing: existing)

        #expect(service.modes[0].templateIds == [existing[0].id])
    }

    @Test("A fail-open mode doesn't adopt the new routine")
    func newTemplateSkipsFailOpenMode() async throws {
        let (service, _) = try makeService()
        await service.ensureLoaded()
        let existing = templates(2)

        // Empty mode — shows everything, so adopting would collapse the list.
        let empty = RoutineMode(name: "Vacation")
        service.addMode(empty)
        service.activate(modeId: empty.id)

        let new = RoutineTemplate(name: "Beach Stretch")
        service.addTemplateToActiveMode(new.id, existing: existing)

        #expect(service.modes[0].templateIds.isEmpty)
        #expect(service.visibleTemplates(from: existing + [new]).count == 3)
    }

    @Test("A mode whose routines were all deleted doesn't adopt the new routine")
    func newTemplateSkipsStaleMode() async throws {
        let (service, _) = try makeService()
        await service.ensureLoaded()
        let existing = templates(2)

        let stale = RoutineMode(name: "Travel", templateIds: [UUID()])
        service.addMode(stale)
        service.activate(modeId: stale.id)

        let new = RoutineTemplate(name: "Airport Walk")
        service.addTemplateToActiveMode(new.id, existing: existing)

        #expect(service.modes[0].templateIds.contains(new.id) == false)
    }

    @Test("Adding a routine through RoutineService enrolls it in the active mode")
    func addTemplateEnrollsInActiveMode() async throws {
        let (modeService, _) = try makeService("add-mode")
        await modeService.ensureLoaded()

        let defaults = try makeIsolatedDefaults("add-mode-templates")
        let routineService = RoutineService(
            persistenceService: UserDefaultsPersistenceService(userDefaults: defaults),
            modeService: modeService
        )
        await routineService.ensureLoaded()

        let existing = routineService.templates
        try #require(existing.count > 1)

        let mode = RoutineMode(name: "Vacation", templateIds: [existing[0].id])
        modeService.addMode(mode)
        modeService.activate(modeId: mode.id)

        let new = RoutineTemplate(name: "Beach Stretch")
        routineService.addTemplate(new)

        #expect(modeService.modes[0].templateIds.contains(new.id))

        let result = await routineService.getSmartTemplateAndSort()
        #expect(result.sorted.contains { $0.id == new.id })
    }
}
