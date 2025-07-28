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
            
            print("🗺️ RoutineSelector: Location update received - \(locationType), \(extendedLocationType)")
            
            self.currentLocationType = locationType
            self.currentExtendedLocationType = extendedLocationType
            
            print("🗺️ RoutineSelector: Updated currentLocationType to \(self.currentLocationType)")
            
            await self.updateContext()
            
            print("🗺️ RoutineSelector: Context updated - location is now \(self.currentContext.location)")
            print("🗺️ RoutineSelector: Final verification - currentLocationType is \(self.currentLocationType)")
        }
        
        await locationCoordinator.startUpdatingLocation()
        
        // Get initial location types
        let (locationType, extendedLocationType) = await locationCoordinator.getCurrentLocationTypes()
        self.currentLocationType = locationType
        self.currentExtendedLocationType = extendedLocationType
        await updateContext()
    }
    
    /// Update the current context
    public func updateContext() async {
        let timeSlot = TimeSlotManager.shared.getCurrentTimeSlot()
        let dayCategory = DayCategoryManager.shared.getCurrentDayCategory()
        
        // Use LocationCoordinator's current location directly to avoid race condition
        let coordinatorLocation = locationCoordinator.currentLocationType
        
        print("🗺️ RoutineSelector.updateContext() Debug:")
        print("   - Before update - currentLocationType: \(currentLocationType)")
        print("   - Before update - currentContext.location: \(currentContext.location)")
        print("   - LocationCoordinator.currentLocationType: \(coordinatorLocation)")
        
        self.currentContext = RoutineContext(
            timeSlot: timeSlot,
            dayCategory: dayCategory,
            location: coordinatorLocation  // Use coordinator's location directly
        )
        
        // Update our cached value to match
        self.currentLocationType = coordinatorLocation
        
        print("   - After update - currentContext.location: \(currentContext.location)")
        print("   - After update - currentLocationType: \(currentLocationType)")
        print("   - Verification - context location matches coordinator: \(currentContext.location == coordinatorLocation)")
    }
    
    /// Select the best routine template based on current context
    public func selectBestTemplate(from templates: [RoutineTemplate]) async -> (template: RoutineTemplate?, reason: String) {
        await updateContext()
        
        // Filter templates with context rules and calculate scores
        print("🔍 RoutineSelector: Current context - Time: \(currentContext.timeSlot.displayName), Day: \(currentContext.dayCategory.displayName), Location: \(currentContext.location.displayName)")
        
        var scoredTemplates: [(template: RoutineTemplate, score: Int)] = []
        
        for template in templates {
            guard let rule = template.contextRule else {
                // Templates without rules get a base score of 1
                print("🔍 Template '\(template.name)': No context rule, score = 1")
                scoredTemplates.append((template, 1))
                continue
            }
            
            let score = await calculateMatchScore(for: rule, context: currentContext)
            let matches = await checkRuleMatches(rule, context: currentContext)
            print("🔍 Template '\(template.name)': matches=\(matches), score=\(score)")
            print("   - TimeSlots: \(rule.timeSlots), DayCategories: \(rule.dayCategoryIds), Priority: \(rule.priority)")
            
            if score > 0 {
                scoredTemplates.append((template, score))
            }
        }
        
        // Sort by score (highest first)
        let sorted = scoredTemplates.sorted { $0.score > $1.score }
        
        print("🔍 RoutineSelector: Sorted templates by score:")
        for (index, scoredTemplate) in sorted.enumerated() {
            print("   \(index + 1). '\(scoredTemplate.template.name)' - Score: \(scoredTemplate.score)")
        }
        
        // Get the best match
        guard let best = sorted.first else {
            return handleNoMatchingTemplate(from: templates)
        }
        
        // Build selection reason
        selectionReason = buildSelectionReason(for: best.template, context: currentContext)
        return (best.template, selectionReason)
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
    
    /// Calculate match score for a context rule
    private func calculateMatchScore(for rule: RoutineContextRule, context: RoutineContext) async -> Int {
        var score = 0
        
        // Time slot matching (highest weight)
        if rule.timeSlots.contains(context.timeSlot) {
            score += 10
        }
        
        // Day category matching (medium weight)
        if rule.dayCategoryIds.contains(context.dayCategory.id) {
            score += 5
        }
        
        // Location matching (medium weight)
        if rule.locationIds.isEmpty {
            // Empty location IDs means "any location" - give small bonus
            score += 1
        } else {
            // Check if current location matches any of the rule's locations
            let locationMatches = await checkLocationMatches(rule: rule, context: context)
            if locationMatches {
                score += 5
            }
        }
        
        // Priority bonus (low weight)
        score += rule.priority
        
        return score
    }
    
    /// Check if the rule matches the current context
    private func checkRuleMatches(_ rule: RoutineContextRule, context: RoutineContext) async -> Bool {
        // Time slot must match
        guard rule.timeSlots.contains(context.timeSlot) else { return false }
        
        // Day category must match
        guard rule.dayCategoryIds.contains(context.dayCategory.id) else { return false }
        
        // Location must match (empty means any location)
        if !rule.locationIds.isEmpty {
            let locationMatches = await checkLocationMatches(rule: rule, context: context)
            guard locationMatches else { return false }
        }
        
        return true
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
        if context.dayCategory.id == "weekend" {
            reasons.append("it's the weekend")
        } else if context.dayCategory.id == "weekday" {
            reasons.append("it's a weekday")
        } else {
            reasons.append("it's a \(context.dayCategory.displayName.lowercased()) day")
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