import Foundation

/// Owns the user's routine modes and which one is active.
///
/// Modes are simple preference data, so they live in UserDefaults alongside
/// day categories and time slots rather than in the SwiftData store.
@Observable @MainActor
public final class RoutineModeService {
    /// App-wide instance used by the UI. Tests inject their own.
    public static let shared = RoutineModeService()

    public private(set) var modes: [RoutineMode] = []
    public private(set) var activeModeId: UUID?

    private let persistenceService: any PersistenceServiceProtocol
    private var loadTask: Task<Void, Never>?
    private var persistTask: Task<Void, Never>?

    public init(persistenceService: any PersistenceServiceProtocol = UserDefaultsPersistenceService()) {
        self.persistenceService = persistenceService
        load()
    }

    /// Suspend until the initial load finished (tests, deep links).
    public func ensureLoaded() async {
        await loadTask?.value
    }

    /// Suspend until the last mutation has been written (tests).
    public func ensurePersisted() async {
        await persistTask?.value
    }

    /// The active mode, or nil when every routine is visible.
    public var activeMode: RoutineMode? {
        guard let activeModeId else { return nil }
        return modes.first { $0.id == activeModeId }
    }

    // MARK: - Activation

    public func activate(modeId: UUID) {
        guard modes.contains(where: { $0.id == modeId }) else { return }
        activeModeId = modeId
        persist()
    }

    public func deactivate() {
        guard activeModeId != nil else { return }
        activeModeId = nil
        persist()
    }

    // MARK: - Editing

    public func addMode(_ mode: RoutineMode) {
        guard !modes.contains(where: { $0.id == mode.id }) else {
            updateMode(mode)
            return
        }
        modes.append(mode)
        persist()
    }

    public func updateMode(_ mode: RoutineMode) {
        guard let index = modes.firstIndex(where: { $0.id == mode.id }) else { return }
        modes[index] = mode
        persist()
    }

    public func deleteMode(withId id: UUID) {
        modes.removeAll { $0.id == id }
        if activeModeId == id {
            activeModeId = nil
        }
        persist()
    }

    /// Enroll a freshly built routine in the active mode so it shows up right away.
    ///
    /// A routine created during Vacation belongs to Vacation — without this it
    /// would be filtered out the moment it was saved.
    ///
    /// Skipped when the active mode isn't actually filtering (it has no
    /// surviving members, so it shows everything): enrolling there would
    /// collapse the Today list to just the new routine.
    ///
    /// - Parameters:
    ///   - templateId: The new routine.
    ///   - templates: The routines that existed *before* this one.
    public func addTemplateToActiveMode(_ templateId: UUID, existing templates: [RoutineTemplate]) {
        guard let activeModeId,
              let index = modes.firstIndex(where: { $0.id == activeModeId }),
              templates.contains(where: { modes[index].templateIds.contains($0.id) }),
              !modes[index].templateIds.contains(templateId)
        else { return }
        modes[index].templateIds.insert(templateId)
        persist()
    }

    /// Drop a deleted routine from every mode so membership counts stay honest.
    public func removeTemplateFromAllModes(_ templateId: UUID) {
        var changed = false
        for index in modes.indices where modes[index].templateIds.contains(templateId) {
            modes[index].templateIds.remove(templateId)
            changed = true
        }
        guard changed else { return }
        persist()
    }

    // MARK: - Filtering

    /// Templates visible under the active mode, input order preserved.
    ///
    /// Fails open on purpose: a mode whose routines were all deleted (or that
    /// was never populated) shows everything rather than an empty Today tab.
    /// `isFiltering(_:)` reports whether anything was actually hidden.
    public func visibleTemplates(from templates: [RoutineTemplate]) -> [RoutineTemplate] {
        guard let mode = activeMode else { return templates }
        let visible = templates.filter { mode.templateIds.contains($0.id) }
        return visible.isEmpty ? templates : visible
    }

    /// True when the active mode currently hides at least one routine.
    public func isFiltering(_ templates: [RoutineTemplate]) -> Bool {
        visibleTemplates(from: templates).count < templates.count
    }

    /// How many of `templates` belong to the given mode.
    public func templateCount(for mode: RoutineMode, in templates: [RoutineTemplate]) -> Int {
        templates.filter { mode.templateIds.contains($0.id) }.count
    }

    // MARK: - Persistence

    private func load() {
        loadTask = Task { @MainActor in
            do {
                if let settings = try await persistenceService.load(RoutineModeSettings.self, forKey: PersistenceKeys.routineModes) {
                    modes = settings.modes
                    // Guard against a stale active id (mode deleted on another device).
                    activeModeId = settings.modes.contains(where: { $0.id == settings.activeModeId }) ? settings.activeModeId : nil
                    return
                }
            } catch {
                LoggingService.shared.error("Failed to load routine modes: \(error.localizedDescription)", category: .app)
            }
            modes = []
            activeModeId = nil
        }
    }

    private func persist() {
        let settings = RoutineModeSettings(modes: modes, activeModeId: activeModeId)
        let previous = persistTask
        persistTask = Task { @MainActor in
            // Serialize writes so a burst of edits can't land out of order.
            await previous?.value
            do {
                try await persistenceService.save(settings, forKey: PersistenceKeys.routineModes)
            } catch {
                LoggingService.shared.error("Failed to save routine modes: \(error.localizedDescription)", category: .app)
            }
        }
    }
}
