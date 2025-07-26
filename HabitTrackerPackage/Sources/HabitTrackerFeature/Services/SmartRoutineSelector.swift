import Foundation
import CoreLocation

/// Service responsible for intelligently selecting routines based on context
@MainActor
@Observable
public final class SmartRoutineSelector {
    /// Current detected context
    public private(set) var currentContext: RoutineContext
    
    /// Location manager for detecting user location
    private let locationManager = LocationManager()
    
    /// Reason for the last selection
    public private(set) var selectionReason: String = ""
    
    public init() {
        self.currentContext = RoutineContext.current()
        
        // Update location when it changes
        Task {
            await startLocationUpdates()
        }
    }
    
    /// Update the current context
    public func updateContext() {
        let location = locationManager.currentLocationType
        self.currentContext = RoutineContext.current(location: location)
    }
    
    /// Select the best routine template based on current context
    public func selectBestTemplate(from templates: [RoutineTemplate]) -> (template: RoutineTemplate?, reason: String) {
        updateContext()
        
        // Filter templates with context rules and calculate scores
        let scoredTemplates = templates.compactMap { template -> (template: RoutineTemplate, score: Int)? in
            guard let rule = template.contextRule else {
                // Templates without rules get a base score of 1
                return (template, 1)
            }
            
            let score = rule.matchScore(for: currentContext)
            return score > 0 ? (template, score) : nil
        }
        
        // Sort by score (highest first)
        let sorted = scoredTemplates.sorted { $0.score > $1.score }
        
        // Get the best match
        guard let best = sorted.first else {
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
        
        // Build selection reason
        selectionReason = buildSelectionReason(for: best.template, context: currentContext)
        return (best.template, selectionReason)
    }
    
    /// Build a human-readable reason for the selection
    private func buildSelectionReason(for template: RoutineTemplate, context: RoutineContext) -> String {
        var reasons: [String] = []
        
        // Time-based reason
        reasons.append("It's \(context.timeSlot.displayName.lowercased())")
        
        // Day-based reason
        if context.dayType == .weekend {
            reasons.append("it's the weekend")
        } else if context.dayType == .weekday {
            reasons.append("it's a weekday")
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
    
    /// Start monitoring location updates
    private func startLocationUpdates() async {
        await locationManager.startUpdatingLocation()
    }
}

/// Manager for handling location services
@MainActor
@Observable
final class LocationManager: NSObject {
    private var locationManager: CLLocationManager?
    private var currentLocation: CLLocation?
    
    /// Current location type based on detected location
    var currentLocationType: LocationType = .unknown
    
    /// Known locations (to be configured by user)
    private var knownLocations: [LocationType: CLLocation] = [:]
    
    override init() {
        super.init()
        setupLocationManager()
    }
    
    private func setupLocationManager() {
        locationManager = CLLocationManager()
        locationManager?.delegate = self
        locationManager?.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager?.distanceFilter = 100 // Update every 100 meters
    }
    
    func startUpdatingLocation() async {
        guard let locationManager else { return }
        
        // Request permission if needed
        let status = locationManager.authorizationStatus
        if status == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }
        
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            locationManager.startUpdatingLocation()
        }
    }
    
    func stopUpdatingLocation() {
        locationManager?.stopUpdatingLocation()
    }
    
    /// Determine location type from current location
    private func determineLocationType(from location: CLLocation) -> LocationType {
        // For now, return unknown
        // In a real implementation, this would compare against saved locations
        // or use geofencing to determine if user is at home, office, etc.
        return .unknown
    }
    
    /// Save a location as a known type
    public func saveLocation(_ location: CLLocation, as type: LocationType) {
        knownLocations[type] = location
        // TODO: Persist to UserDefaults or other storage
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationManager: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        Task { @MainActor in
            self.currentLocation = location
            self.currentLocationType = determineLocationType(from: location)
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed with error: \(error)")
    }
    
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            Task { @MainActor in
                self.locationManager?.startUpdatingLocation()
            }
        }
    }
}