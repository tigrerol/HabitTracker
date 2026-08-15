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

    public init(persistenceService: any PersistenceServiceProtocol = UserDefaultsPersistenceService()) {
        self.persistenceService = persistenceService
        load()
    }

    /// Suspend until the initial load finished (tests, deep links).
    public func ensureLoaded() async {
        await loadTask?.value
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
        Task { @MainActor in
            do {
                try await persistenceService.save(settings, forKey: PersistenceKeys.routineModes)
            } catch {
                LoggingService.shared.error("Failed to save routine modes: \(error.localizedDescription)", category: .app)
            }
        }
    }
}
