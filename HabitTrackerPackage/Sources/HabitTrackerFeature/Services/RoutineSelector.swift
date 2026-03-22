import Foundation

/// Service responsible for intelligently selecting routines based on context
@MainActor
@Observable
public final class RoutineSelector {
    /// Current detected context
    public private(set) var currentContext: RoutineContext
    
    /// Location coordinator for location data
    public let locationCoordinator: LocationCoordinator
    
    /// Reason for the last selection
    public private(set) var selectionReason: String = ""
    
    /// Current location types (cached from LocationService)
    private var currentLocationType: LocationType = .unknown
    private var currentExtendedLocationType: ExtendedLocationType = .builtin(.unknown)
    
    /// Throttling for context updates to reduce performance impact
    private var lastContextUpdate: Date = Date.distantPast
    
    public init(locationCoordinator: LocationCoordinator = LocationCoordinator.shared) {
        self.locationCoordinator = locationCoordinator
        self.currentContext = RoutineContext.current()
        
        // Set up location updates
        Task {
            await setupLocationUpdates()
        }
    }
    
    /// Set up location monitoring
    private func setupLocationUpdates() async {
        locationCoordinator.setLocationUpdateCallback { [weak self] locationType, extendedLocationType in
            guard let self = self else { return }

            // Check if location actually changed to avoid unnecessary updates
            guard self.currentLocationType != locationType || self.currentExtendedLocationType != extendedLocationType else {
                return
            }

            self.currentLocationType = locationType
            self.currentExtendedLocationType = extendedLocationType

            // Location changed — always force an immediate context update,
            // bypassing the throttle that prevents redundant timer-based refreshes.
            await self.updateContext(force: true)
        }

        await locationCoordinator.startUpdatingLocation()

        // Get initial location types
        let (locationType, extendedLocationType) = await locationCoordinator.getCurrentLocationTypes()
        self.currentLocationType = locationType
        self.currentExtendedLocationType = extendedLocationType
        await updateContext(force: true)
    }

    /// Update the current context
    public func updateContext(force: Bool = false) async {
        // Throttle context updates to prevent performance issues
        let now = Date()
        if !force && now.timeIntervalSince(lastContextUpdate) < AppConstants.Location.contextUpdateInterval {
            return
        }
        lastContextUpdate = now

        let timeSlot = TimeSlotManager.shared.getCurrentTimeSlot()
        let dayCategories = DayCategoryManager.shared.getCurrentDayCategories()

        // Use LocationCoordinator's current location directly to avoid race condition
        let coordinatorLocation = locationCoordinator.currentLocationType

        self.currentContext = RoutineContext(
            timeSlot: timeSlot,
            dayCategories: dayCategories,
            location: coordinatorLocation
        )

        // Update our cached value to match
        self.currentLocationType = coordinatorLocation
    }
    
    /// Score all templates, return sorted list + best match with reason in a single pass.
    public func selectAndSortTemplates(_ templates: [RoutineTemplate]) async -> (sorted: [RoutineTemplate], best: RoutineTemplate?, reason: String) {
        await updateContext(force: true)

        var scored: [(template: RoutineTemplate, score: Int)] = []
        for template in templates {
            guard let rule = template.contextRule else {
                scored.append((template, 0))
                continue
            }
            let score = await calculateMatchScore(for: rule, context: currentContext)
            scored.append((template, score))
        }

        let sorted = scored.sorted { $0.score > $1.score }
        let sortedTemplates = sorted.map(\.template)

        // Best match is the highest-scoring template with score > 0
        if let best = sorted.first, best.score > 0 {
            selectionReason = buildSelectionReason(for: best.template, context: currentContext)
            return (sortedTemplates, best.template, selectionReason)
        }

        // Fallback
        let fallback = handleNoMatchingTemplate(from: templates)
        return (sortedTemplates, fallback.template, fallback.reason)
    }
    
    /// Handle case when no templates match the current context
    private func handleNoMatchingTemplate(from templates: [RoutineTemplate]) -> (template: RoutineTemplate?, reason: String) {
        // Fallback to default or most recently used
        if let defaultTemplate = templates.first(where: { $0.isDefault }) {
            selectionReason = "Using default routine"
            return (defaultTemplate, selectionReason)
        }
        
        let lastUsed = templates
            .filter { $0.lastUsedAt != nil }
            .max { ($0.lastUsedAt ?? Date.distantPast) < ($1.lastUsedAt ?? Date.distantPast) }
        if let lastUsed = lastUsed {
            selectionReason = "Using most recently used routine"
            return (lastUsed, selectionReason)
        }
        
        selectionReason = "No matching routine found"
        return (templates.first, selectionReason)
    }
    
    /// Calculate match score for a context rule.
    /// All non-empty dimensions must match or the score is 0.
    /// Score = priority * 1000 + day match (300) + time match (200) + location specificity (100 explicit, 10 any).
    private func calculateMatchScore(for rule: RoutineContextRule, context: RoutineContext) async -> Int {
        // Day category: must match if specified
        let dayMatch = rule.dayCategoryIds.isEmpty || context.dayCategories.contains(where: { rule.dayCategoryIds.contains($0.id) })
        guard dayMatch else { return 0 }

        // Time slot: must match if specified
        let timeMatch = rule.timeSlots.isEmpty || rule.timeSlots.contains(context.timeSlot)
        guard timeMatch else { return 0 }

        // Location: must match if specified
        if !rule.locationIds.isEmpty {
            let locationMatches = await checkLocationMatches(rule: rule, context: context)
            guard locationMatches else { return 0 }
        }

        // All required dimensions match — calculate score
        var score = rule.priority * 1000

        if !rule.dayCategoryIds.isEmpty {
            score += 300
        }
        if !rule.timeSlots.isEmpty {
            score += 200
        }
        if !rule.locationIds.isEmpty {
            // Explicit location match scores higher than "any location"
            score += 100
        } else {
            score += 10
        }

        return max(score, 1)
    }
    
    /// Check if current location matches rule's location requirements
    private func checkLocationMatches(rule: RoutineContextRule, context: RoutineContext) async -> Bool {
        // Check built-in location types
        if rule.locationIds.contains(context.location.rawValue) {
            return true
        }
        
        // Check custom locations
        let allCustomLocations = locationCoordinator.getAllCustomLocations()
        for customLocation in allCustomLocations {
            if rule.locationIds.contains(customLocation.id.uuidString) {
                // Check if we're currently at this custom location
                if case .custom(let currentCustomId) = currentExtendedLocationType,
                   currentCustomId == customLocation.id {
                    return true
                }
            }
        }
        
        return false
    }
    
    /// Build a human-readable reason for the selection
    private func buildSelectionReason(for template: RoutineTemplate, context: RoutineContext) -> String {
        var reasons: [String] = []
        
        // Time-based reason
        reasons.append("It's \(context.timeSlot.displayName.lowercased())")
        
        // Day-based reason
        let categoryIds = Set(context.dayCategories.map(\.id))
        if categoryIds == Set(["weekend"]) {
            reasons.append("it's the weekend")
        } else if categoryIds == Set(["weekday"]) {
            reasons.append("it's a weekday")
        } else {
            let names = context.dayCategories.map(\.displayName).joined(separator: " & ")
            reasons.append("it's a \(names.lowercased()) day")
        }
        
        // Location-based reason
        if context.location != .unknown {
            reasons.append("you're at \(context.location.displayName.lowercased())")
        }
        
        // Combine reasons
        if reasons.isEmpty {
            return "Selected '\(template.name)' as your routine"
        } else {
            let reasonText = reasons.joined(separator: " and ")
            return "Selected '\(template.name)' because \(reasonText)"
        }
    }
    
    /// Get the current context (for external use)
    public func getCurrentContext() -> RoutineContext {
        return currentContext
    }
    
    /// Force update location (for testing or manual refresh)
    public func refreshLocation() async {
        await locationCoordinator.startUpdatingLocation()
    }
    
}