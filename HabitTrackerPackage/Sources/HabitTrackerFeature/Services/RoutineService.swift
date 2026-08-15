import Foundation
import SwiftUI
import HabitTrackerWidgetShared
#if canImport(WidgetKit)
import WidgetKit
#endif

// MARK: - Notifications
extension Notification.Name {
    static let routineQueueDidChange = Notification.Name("routineQueueDidChange")
}

/// Service for managing routine templates and sessions
@MainActor
@Observable
public final class RoutineService {
    /// App-wide singleton — ensures only one RoutineSelector is ever created,
    /// preventing zombie Tasks from overwriting LocationCoordinator's callback.
    /// Runs on SwiftData (templates + session history); the default init below
    /// stays UserDefaults-backed for previews and tests.
    public static let shared = RoutineService(
        persistenceService: DataModelConfiguration.sharedPersistence
    )
    public private(set) var templates: [RoutineTemplate] = []
    public private(set) var currentSession: RoutineSession?
    public private(set) var pausedSessions: [PausedSessionSnapshot] = []
    public private(set) var moodRatings: [MoodRating] = []
    
    /// Routine selector for context-aware selection
    public let routineSelector = RoutineSelector()
    
    /// Habit snippet service for managing reusable habit collections
    @MainActor public let snippetService = HabitSnippetService()

    /// Narrows the visible routine set while a mode (Vacation, Sick Day, …) is active.
    public let modeService: RoutineModeService

    private let persistenceService: any PersistenceServiceProtocol

    /// Task handles for the async init loads — await ensureLoaded() before
    /// acting on templates or paused sessions (deep links, tests).
    private var templatesLoadTask: Task<Void, Never>?
    private var pausedSessionsLoadTask: Task<Void, Never>?
    private var moodRatingsLoadTask: Task<Void, Never>?

    /// Serializes mood persistence so rapid ratings can't write out of order.
    private var moodPersistTask: Task<Void, Never>?

    /// Single-flight debounce so bursts of mutations collapse into one
    /// (expensive) widget snapshot refresh + timeline reload.
    private var widgetRefreshTask: Task<Void, Never>?

    /// Initialize with dependency injection
    public init(
        persistenceService: any PersistenceServiceProtocol = UserDefaultsPersistenceService(),
        modeService: RoutineModeService = .shared
    ) {
        self.persistenceService = persistenceService
        self.modeService = modeService
        loadTemplates()
        loadPausedSessions()
        loadMoodRatings()

        // Refresh widget snapshot when location updates land, so the smart-selected
        // template the widget shows matches the in-app Quick Start once GPS resolves.
        // RoutineSelector also observes location updates separately for its own context;
        // we register independently so neither observer can break the other.
        routineSelector.locationCoordinator.addLocationUpdateCallback { [weak self] _, _ in
            self?.scheduleWidgetRefresh()
        }
    }

    /// Suspend until the initial template and paused-session loads (including
    /// interrupted-session recovery) have completed.
    public func ensureLoaded() async {
        await templatesLoadTask?.value
        await pausedSessionsLoadTask?.value
        await moodRatingsLoadTask?.value
    }
    
    /// Load templates from persistence, or create sample templates if none exist
    private func loadTemplates() {
        templatesLoadTask = Task { @MainActor in
            do {
                if let loadedTemplates = try await persistenceService.load([RoutineTemplate].self, forKey: PersistenceKeys.routineTemplates) {
                    templates = loadedTemplates
                    scheduleWidgetRefresh()
                    return
                }
            } catch {
                ErrorHandlingService.shared.handleDataError(
                    .decodingFailed(type: "RoutineTemplate", underlyingError: error),
                    key: PersistenceKeys.routineTemplates,
                    operation: "load"
                )
            }
            
            // First time launch or failed to load - create sample templates
            LoggingService.shared.info(
                "Creating sample templates for first launch",
                category: .routine,
                metadata: ["reason": "no_existing_templates"]
            )
            loadSampleTemplates()
            await persistTemplates()
        }
    }
    
    /// Load predefined sample templates
    private func loadSampleTemplates() {
        templates = [
            createOfficeTemplate(),
            createHomeOfficeTemplate(),
            createWeekendTemplate(),
            createAfternoonTemplate()
        ]
    }
    
    /// Persist templates using PersistenceService
    private func persistTemplates() async {
        do {
            try await persistenceService.save(templates, forKey: PersistenceKeys.routineTemplates)
        } catch {
            ErrorHandlingService.shared.handleDataError(
                .encodingFailed(type: "RoutineTemplate", underlyingError: error),
                key: PersistenceKeys.routineTemplates,
                operation: "save"
            )
        }
        scheduleWidgetRefresh()
    }
    
    /// Start a new routine session with the given template
    public func startSession(with template: RoutineTemplate) throws {
        // Check if session is already active
        guard currentSession == nil else {
            let error = RoutineError.sessionAlreadyActive
            ErrorHandlingService.shared.handleRoutineError(error, sessionId: currentSession?.id)
            throw error
        }
        
        // Validate template — a wrapper routine may own no habits of its own,
        // so measure the resolved (include-expanded) habit list.
        guard !resolvedTemplate(template).habits.isEmpty else {
            let error = RoutineError.templateValidationFailed(reason: "Template has no habits")
            ErrorHandlingService.shared.handleRoutineError(error, templateId: template.id)
            throw error
        }
        
        // Validate template exists in our collection
        guard templates.contains(where: { $0.id == template.id }) else {
            let error = RoutineError.templateNotFound(id: template.id)
            ErrorHandlingService.shared.handleRoutineError(error, templateId: template.id)
            throw error
        }
        
        currentSession = RoutineSession(template: resolvedTemplate(template))

        // Update template's last used date
        if let index = templates.firstIndex(where: { $0.id == template.id }) {
            templates[index].lastUsedAt = Date()
            Task { await persistTemplates() }
        }
    }
    
    /// Complete the current session
    public func completeCurrentSession() throws {
        guard let session = currentSession else {
            let error = RoutineError.noActiveSession
            ErrorHandlingService.shared.handleRoutineError(error)
            throw error
        }

        // Complete the session manually
        session.forceComplete()

        let data = RoutineSessionData(
            id: session.id,
            startedAt: session.startedAt,
            completedAt: session.completedAt,
            currentHabitIndex: session.currentHabitIndex,
            completions: session.completions,
            modifications: session.modifications
        )
        let templateId = session.template.id
        Task {
            await persistenceService.saveRoutineSession(data, for: templateId)
            // Only after the completion is durably recorded is the interrupted
            // snapshot safe to discard — a kill before this point leaves the
            // snapshot behind for recovery instead of silently losing the session.
            await persistenceService.delete(forKey: PersistenceKeys.interruptedSession)
            scheduleWidgetRefresh()
        }

        currentSession = nil
    }
    
    /// Cancel the current session
    public func cancelCurrentSession() throws {
        guard let session = currentSession else {
            let error = RoutineError.noActiveSession
            ErrorHandlingService.shared.handleRoutineError(error)
            throw error
        }
        
        // Log the cancellation for analytics/debugging
        LoggingService.shared.info("Routine session cancelled", category: .routine, metadata: [
            "sessionId": session.id.uuidString,
            "templateName": session.template.name,
            "progress": String(session.progress),
            "completedHabits": String(session.completions.filter { !$0.isSkipped }.count),
            "totalHabits": String(session.activeHabits.count)
        ])
        
        // Clear the current session without completing it
        currentSession = nil
        clearInterruptedSessionSnapshot()
    }
    
    /// Add a mood rating for the completed session
    public func addMoodRating(_ mood: Mood, for sessionId: UUID, notes: String? = nil) {
        let rating = MoodRating(
            sessionId: sessionId,
            rating: mood,
            notes: notes
        )
        moodRatings.append(rating)

        // Chain persists so consecutive ratings can never write out of order.
        let snapshot = moodRatings
        let previous = moodPersistTask
        moodPersistTask = Task {
            await previous?.value
            await persistenceService.saveMoodRatings(snapshot)
        }
    }

    /// Load persisted mood ratings
    private func loadMoodRatings() {
        moodRatingsLoadTask = Task { @MainActor in
            let loaded = await persistenceService.loadMoodRatings()
            // Merge: ratings added before the load finished must survive
            let known = Set(moodRatings.map(\.id))
            moodRatings = loaded.filter { !known.contains($0.id) } + moodRatings
        }
    }
    
    /// Get the most recently used template (for quick start)
    public var lastUsedTemplate: RoutineTemplate? {
        templates
            .filter { $0.lastUsedAt != nil }
            .max { ($0.lastUsedAt ?? Date.distantPast) < ($1.lastUsedAt ?? Date.distantPast) }
    }
    
    /// Get default template if set
    public var defaultTemplate: RoutineTemplate? {
        templates.first { $0.isDefault }
    }
    
    /// Score, sort, and select the best template based on current context — single pass.
    /// An active routine mode narrows the candidate set first, so both the Today
    /// list and the widget's Quick Start stay inside the mode.
    @MainActor
    public func getSmartTemplateAndSort() async -> (sorted: [RoutineTemplate], best: RoutineTemplate?, reason: String) {
        await routineSelector.selectAndSortTemplates(modeService.visibleTemplates(from: templates))
    }
    
    /// Expand a template's routine includes into a flat, runnable copy.
    /// Cheap for plain routines — returns them unchanged.
    public func resolvedTemplate(_ template: RoutineTemplate) -> RoutineTemplate {
        RoutineComposer.resolve(template, in: templates)
    }

    /// Routines that include the given routine as a block.
    public func templatesIncluding(_ templateId: UUID) -> [RoutineTemplate] {
        RoutineComposer.templatesIncluding(templateId, in: templates)
    }

    /// Add a new template
    public func addTemplate(_ template: RoutineTemplate) {
        templates.append(template)
        
        // If this is the first template or marked as default, make it default
        if templates.count == 1 || template.isDefault {
            // Unset other defaults if this is default
            if template.isDefault {
                for index in templates.indices {
                    if templates[index].id != template.id {
                        templates[index].isDefault = false
                    }
                }
            }
        }
        
        Task { await persistTemplates() }
    }
    
    /// Update an existing template
    public func updateTemplate(_ template: RoutineTemplate) {
        if let index = templates.firstIndex(where: { $0.id == template.id }) {
            templates[index] = template
            
            // Handle default status
            if template.isDefault {
                for i in templates.indices where i != index {
                    templates[i].isDefault = false
                }
            }
            
            Task { await persistTemplates() }
        }
    }
    
    /// Compute streak data for every routine that has a weekly target.
    /// Results are sorted by `lastUsedAt` descending (nils last), matching
    /// the order used elsewhere in the app.
    @MainActor
    public func computeStreaks(now: Date) async -> [StreakCalculator.RoutineStreakData] {
        var results: [StreakCalculator.RoutineStreakData] = []
        let sorted = templates.sorted { lhs, rhs in
            switch (lhs.lastUsedAt, rhs.lastUsedAt) {
            case let (l?, r?): return l > r
            case (_?, nil):    return true
            case (nil, _?):    return false
            case (nil, nil):   return lhs.createdAt > rhs.createdAt
            }
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4

        for template in sorted where template.weeklyTarget != nil {
            let sessions = await persistenceService.loadRoutineSessions(for: template.id)
            if let data = StreakCalculator.compute(
                for: template,
                sessions: sessions,
                now: now,
                calendar: calendar
            ) {
                results.append(data)
            }
        }
        return results
    }

    /// Delete a template
    public func deleteTemplate(withId id: UUID) {
        templates.removeAll { $0.id == id }
        modeService.removeTemplateFromAllModes(id)

        // Drop dangling blocks so wrapper routines don't silently shrink at
        // start; the composer would skip them anyway, but this keeps the
        // builder honest about what a routine contains.
        for index in templates.indices where templates[index].includes.contains(where: { $0.templateId == id }) {
            templates[index].includes.removeAll { $0.templateId == id }
        }

        Task { await persistTemplates() }
    }
    
    /// Handle selection of a conditional habit option
    public func handleConditionalOptionSelection(
        option: ConditionalOption,
        for habitId: UUID,
        question: String
    ) {
        guard let session = currentSession else { return }
        
        // Log the response
        let response = ConditionalResponse(
            habitId: habitId,
            question: question,
            selectedOptionId: option.id,
            selectedOptionText: option.text,
            routineId: session.id,
            wasSkipped: false
        )
        ConditionalHabitService.shared.recordResponse(response)

        // Get the habits from the selected path
        let pathHabits = option.habits
        
        // Find the current position in the active habits
        let currentHabitIndex = session.currentHabitIndex
        
        // If there are habits in the path, inject them into the session
        if !pathHabits.isEmpty {
            let activeHabits = session.activeHabits
            
            // Create a reordered habit list that inserts the path habits after the current conditional
            var newOrder: [Habit] = []
            
            // Add habits up to and including current position
            for i in 0...currentHabitIndex {
                if i < activeHabits.count {
                    var habit = activeHabits[i]
                    habit.order = i  // Ensure correct sequential order
                    newOrder.append(habit)
                }
            }
            
            // Insert the path habits with sequential order values
            for (index, habit) in pathHabits.enumerated() {
                var pathHabit = habit
                pathHabit.order = currentHabitIndex + 1 + index  // Sequential after current
                newOrder.append(pathHabit)
            }
            
            // Add remaining habits with adjusted sequential order values
            if currentHabitIndex + 1 < activeHabits.count {
                for i in (currentHabitIndex + 1)..<activeHabits.count {
                    var remainingHabit = activeHabits[i]
                    remainingHabit.order = currentHabitIndex + 1 + pathHabits.count + (i - currentHabitIndex - 1)
                    newOrder.append(remainingHabit)
                }
            }
            
            // Apply the reordering modification
            session.reorderHabits(newOrder)
        }
        
        // Complete the conditional habit and advance to the next habit (which should be the first injected habit)
        
        session.completeConditionalHabit(
            habitId: habitId,
            duration: nil,
            notes: "Selected: \(option.text)"
        )
        
        // Move to the next habit (first injected habit if pathHabits is not empty,
        // or the next habit in the original sequence if pathHabits is empty)
        session.goToHabit(at: session.currentHabitIndex + 1)
        
        // Post notification that routine queue changed
        NotificationCenter.default.post(name: .routineQueueDidChange, object: nil)
    }
    
    // MARK: - Pause & Resume

    /// Pause the current session, saving a snapshot for later resumption
    public func pauseCurrentSession() throws {
        guard let session = currentSession else {
            let error = RoutineError.noActiveSession
            ErrorHandlingService.shared.handleRoutineError(error)
            throw error
        }

        let snapshot = session.toPausedSnapshot()
        pausedSessions.append(snapshot)
        currentSession = nil
        Task {
            await persistPausedSessions()
            // Delete the autosave only after the paused list is durable.
            await persistenceService.delete(forKey: PersistenceKeys.interruptedSession)
        }

        LoggingService.shared.info("Routine session paused", category: .routine, metadata: [
            "sessionId": snapshot.id.uuidString,
            "templateName": snapshot.template.name,
            "progress": String(snapshot.progress),
            "completedHabits": String(snapshot.completedCount),
            "totalHabits": String(snapshot.totalCount)
        ])
    }

    /// Resume a previously paused session, auto-pausing the current session if one is active
    public func resumeSession(withId id: UUID) throws {
        guard let snapshotIndex = pausedSessions.firstIndex(where: { $0.id == id }) else {
            let error = RoutineError.pausedSessionNotFound(id: id)
            ErrorHandlingService.shared.handleRoutineError(error)
            throw error
        }

        // Auto-pause current session if one is active
        if currentSession != nil {
            try pauseCurrentSession()
        }

        let snapshot = pausedSessions.remove(at: snapshotIndex)
        currentSession = RoutineSession(from: snapshot)
        Task { await persistPausedSessions() }

        LoggingService.shared.info("Routine session resumed", category: .routine, metadata: [
            "sessionId": snapshot.id.uuidString,
            "templateName": snapshot.template.name,
            "progress": String(snapshot.progress)
        ])
    }

    /// Discard a paused session without resuming
    public func discardPausedSession(withId id: UUID) {
        pausedSessions.removeAll { $0.id == id }
        Task { await persistPausedSessions() }
    }

    /// Load paused sessions from persistence
    private func loadPausedSessions() {
        pausedSessionsLoadTask = Task { @MainActor in
            do {
                if let loaded = try await persistenceService.load([PausedSessionSnapshot].self, forKey: PersistenceKeys.pausedSessions) {
                    // Clean up stale sessions (older than 7 days)
                    let cutoff = Date().addingTimeInterval(-7 * 24 * 60 * 60)
                    let fresh = loaded.filter { $0.pausedAt > cutoff }
                    pausedSessions = fresh
                    if fresh.count < loaded.count {
                        LoggingService.shared.info("Cleaned up stale paused sessions", category: .routine, metadata: [
                            "removed": String(loaded.count - fresh.count)
                        ])
                        await persistPausedSessions()
                    }
                }
            } catch {
                ErrorHandlingService.shared.handleDataError(
                    .decodingFailed(type: "PausedSessionSnapshot", underlyingError: error),
                    key: PersistenceKeys.pausedSessions,
                    operation: "load"
                )
            }
            await recoverInterruptedSession()
        }
    }

    // MARK: - Interruption Recovery

    /// Snapshot the active session so it survives app termination.
    /// Called when the app leaves the foreground; the snapshot is discarded
    /// when the session ends normally (complete, cancel, or explicit pause).
    public func autosaveCurrentSession() async {
        guard let session = currentSession else { return }
        let snapshot = session.toPausedSnapshot()
        do {
            try await persistenceService.save(snapshot, forKey: PersistenceKeys.interruptedSession)
        } catch {
            ErrorHandlingService.shared.handleDataError(
                .encodingFailed(type: "PausedSessionSnapshot", underlyingError: error),
                key: PersistenceKeys.interruptedSession,
                operation: "save"
            )
        }
    }

    private func clearInterruptedSessionSnapshot() {
        Task { await persistenceService.delete(forKey: PersistenceKeys.interruptedSession) }
    }

    /// Coalesce widget refreshes: bursts of mutations (edits, recovery,
    /// startup loads) collapse into a single refresh after a short quiet period.
    public func scheduleWidgetRefresh(callSite: String = #function) {
        widgetRefreshTask?.cancel()
        widgetRefreshTask = Task { [callSite] in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await refreshWidgetSnapshot(callSite: callSite)
        }
    }

    /// Move an interrupted-session snapshot (app killed mid-routine) into the
    /// paused list so the user can resume it from the Today tab.
    func recoverInterruptedSession() async {
        guard let snapshot = try? await persistenceService.load(PausedSessionSnapshot.self, forKey: PersistenceKeys.interruptedSession) else { return }
        await persistenceService.delete(forKey: PersistenceKeys.interruptedSession)
        guard !pausedSessions.contains(where: { $0.id == snapshot.id }) else { return }

        // The snapshot delete races app termination, so a finished session can
        // leave one behind — never resurrect a session that already completed.
        let history = await persistenceService.loadRoutineSessions(for: snapshot.templateId)
        if history.contains(where: { $0.id == snapshot.id && $0.completedAt != nil }) {
            LoggingService.shared.info("Discarded stale interrupted snapshot for completed session", category: .routine, metadata: [
                "sessionId": snapshot.id.uuidString
            ])
            return
        }

        pausedSessions.append(snapshot)
        await persistPausedSessions()
        LoggingService.shared.info("Recovered interrupted session into paused list", category: .routine, metadata: [
            "sessionId": snapshot.id.uuidString,
            "templateName": snapshot.template.name,
            "progress": String(snapshot.progress)
        ])
    }

    /// Persist paused sessions
    private func persistPausedSessions() async {
        do {
            try await persistenceService.save(pausedSessions, forKey: PersistenceKeys.pausedSessions)
        } catch {
            ErrorHandlingService.shared.handleDataError(
                .encodingFailed(type: "PausedSessionSnapshot", underlyingError: error),
                key: PersistenceKeys.pausedSessions,
                operation: "save"
            )
        }
        scheduleWidgetRefresh()
    }

    /// Build a fresh WidgetSnapshot from current state and persist it to the App Group
    /// container, then ask WidgetKit to reload all timelines.
    private func refreshWidgetSnapshot(callSite: String = #function) async {
        let smartBest = await getSmartTemplateAndSort().best
        let defaultT = defaultTemplate
        let lastUsedT = lastUsedTemplate
        let firstT = templates.first

        let quickStartTemplate = smartBest ?? defaultT ?? lastUsedT ?? firstT

        let chosenSource: String
        if smartBest != nil { chosenSource = "smart" }
        else if defaultT != nil { chosenSource = "default" }
        else if lastUsedT != nil { chosenSource = "lastUsed" }
        else if firstT != nil { chosenSource = "first" }
        else { chosenSource = "none" }

        let ctx = routineSelector.currentContext
        LoggingService.shared.info(
            "WidgetSnapshot: refresh",
            category: .routine,
            metadata: [
                "callSite": callSite,
                "chosenSource": chosenSource,
                "chosen": quickStartTemplate?.name ?? "nil",
                "smartBest": smartBest?.name ?? "nil",
                "defaultTemplate": defaultT?.name ?? "nil",
                "lastUsedTemplate": lastUsedT?.name ?? "nil",
                "ctx.timeSlot": String(describing: ctx.timeSlot),
                "ctx.dayCategoryIds": ctx.dayCategories.map(\.id).joined(separator: ","),
                "ctx.location": ctx.location.rawValue,
                "ctx.extendedLocation": String(describing: ctx.extendedLocation),
                "templateCount": String(templates.count)
            ]
        )

        let topRoutine = quickStartTemplate.map { template in
            WidgetSnapshot.TopRoutine(
                name: template.name,
                habitCount: resolvedTemplate(template).activeHabitsCount,
                colorHex: template.color,
                templateId: template.id
            )
        }

        let pausedSession: WidgetSnapshot.PausedSession? = pausedSessions
            .sorted { $0.pausedAt > $1.pausedAt }
            .first
            .map { snapshot in
                WidgetSnapshot.PausedSession(
                    routineName: snapshot.template.name,
                    pausedAt: snapshot.pausedAt,
                    currentStepIndex: snapshot.currentHabitIndex,
                    totalSteps: snapshot.activeHabitsSnapshot.count,
                    sessionId: snapshot.id
                )
            }

        let streakData = await computeStreaks(now: Date())
        let streaks = streakData
            .sorted { $0.totalStreak > $1.totalStreak }
            .prefix(3)
            .map { data in
                WidgetSnapshot.StreakEntry(
                    routineName: data.template.name,
                    totalStreak: data.totalStreak,
                    target: data.target,
                    completedThisWeek: data.currentWeek.completedDayCount
                )
            }

        let snapshot = WidgetSnapshot(
            generatedAt: Date(),
            topRoutine: topRoutine,
            pausedSession: pausedSession,
            streaks: Array(streaks)
        )

        do {
            try WidgetSnapshotStore.shared.write(snapshot)
            #if canImport(WidgetKit)
            WidgetCenter.shared.reloadAllTimelines()
            #endif
        } catch {
            LoggingService.shared.error(
                "Failed to write widget snapshot",
                category: .routine,
                metadata: ["error": String(describing: error)]
            )
        }
    }

    /// Handle skipping a conditional habit
    public func skipConditionalHabit(habitId: UUID, question: String) {
        guard let session = currentSession else { return }
        
        // Log the skip response
        let response = ConditionalResponse.skip(
            habitId: habitId,
            question: question,
            routineId: session.id
        )
        ConditionalHabitService.shared.recordResponse(response)
    }
}

// MARK: - Sample Templates
extension RoutineService {
    private func createOfficeTemplate() -> RoutineTemplate {
        let habits = HabitFactory.createOfficeMorningHabits()
        
        // Office routine is for weekday mornings at the office
        let contextRule = RoutineContextRule(
            timeSlots: [.earlyMorning, .morning],
            dayCategoryIds: ["weekday"],
            locationIds: ["office"],
            priority: 2
        )
        
        return RoutineTemplate(
            name: "Office Day",
            description: "Morning routine for office workdays",
            habits: habits,
            color: "#007AFF",
            contextRule: contextRule
        )
    }
    
    private func createHomeOfficeTemplate() -> RoutineTemplate {
        let habits = HabitFactory.createHomeOfficeHabits()
        
        // Home office routine is for weekday mornings at home
        let contextRule = RoutineContextRule(
            timeSlots: [.earlyMorning, .morning, .lateMorning],
            dayCategoryIds: ["weekday"],
            locationIds: ["home"],
            priority: 2
        )
        
        return RoutineTemplate(
            name: "Home Office",
            description: "Morning routine for working from home",
            habits: habits,
            color: "#34C759",
            isDefault: false,
            contextRule: contextRule
        )
    }
    
    private func createWeekendTemplate() -> RoutineTemplate {
        let habits = HabitFactory.createWeekendHabits()
        
        // Weekend routine is for any time on weekends, any location
        let contextRule = RoutineContextRule(
            timeSlots: [.earlyMorning, .morning, .lateMorning, .afternoon, .evening, .night],
            dayCategoryIds: ["weekend"],
            locationIds: [], // Any location
            priority: 1
        )
        
        return RoutineTemplate(
            name: "Weekend",
            description: "Relaxed weekend morning routine",
            habits: habits,
            color: "#FDCB6E",
            contextRule: contextRule
        )
    }
    
    /// Create afternoon routine template
    private func createAfternoonTemplate() -> RoutineTemplate {
        let habits = HabitFactory.createAfternoonHabits()
        
        // Afternoon routine is for weekday and weekend afternoons/evenings at any location
        let contextRule = RoutineContextRule(
            timeSlots: [.afternoon, .evening],
            dayCategoryIds: ["weekday", "weekend"],
            locationIds: [], // Any location
            priority: 3 // Higher priority than weekend template
        )
        
        return RoutineTemplate(
            name: "Afternoon Focus",
            description: "Afternoon productivity and evening prep",
            habits: habits,
            color: "#FF9500",
            isDefault: false,
            contextRule: contextRule
        )
    }
}