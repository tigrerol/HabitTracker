import Foundation
import CoreLocation

/// Service responsible for tracking device location using CoreLocation
public actor LocationTrackingService {
    @MainActor private var locationManager: CLLocationManager?
    @MainActor private var locationDelegate: LocationManagerDelegate?
    
    /// Current location with atomic updates
    private var _currentLocation: CLLocation?
    
    /// Thread-safe getter for current location
    private(set) var currentLocation: CLLocation? {
        get { _currentLocation }
        set { _currentLocation = newValue }
    }
    
    /// Callback for location updates
    private var locationUpdateCallback: (@Sendable (CLLocation) async -> Void)?
    
    /// Initialize the tracking service
    public init() {}
    
    /// Set up location manager (must be called from main actor)
    @MainActor
    public func setupLocationManager() {
        Task { [weak self] in
            await self?.internalSetupLocationManager()
        }
    }
    
    private func internalSetupLocationManager() async {
        let delegate = LocationManagerDelegate(service: self)
        
        await MainActor.run {
            locationManager = CLLocationManager()
            locationDelegate = delegate
            locationManager?.delegate = locationDelegate
            locationManager?.desiredAccuracy = kCLLocationAccuracyHundredMeters
            locationManager?.distanceFilter = AppConstants.Location.distanceFilter
        }
    }
    
    /// Set callback for location updates
    public func setLocationUpdateCallback(_ callback: @escaping @Sendable (CLLocation) async -> Void) {
        self.locationUpdateCallback = callback
    }
    
    /// Start updating location
    public func startUpdatingLocation() async {
        await MainActor.run {
            guard let locationManager = self.locationManager else { return }
            let status = locationManager.authorizationStatus
            if status == .notDetermined {
                #if os(iOS)
                locationManager.requestWhenInUseAuthorization()
                #elseif os(macOS)
                locationManager.requestAlwaysAuthorization()
                #endif
            } else {
                #if os(iOS)
                if status == .authorizedAlways || status == .authorizedWhenInUse {
                    locationManager.startUpdatingLocation()
                }
                #elseif os(macOS)
                if status == .authorizedAlways {
                    locationManager.startUpdatingLocation()
                }
                #endif
            }
        }
    }
    
    /// Stop updating location
    public func stopUpdatingLocation() async {
        await MainActor.run {
            guard let locationManager = self.locationManager else { return }
            locationManager.stopUpdatingLocation()
        }
    }
    
    /// Get current location
    public func getCurrentLocation() -> CLLocation? {
        return currentLocation
    }
    
    /// Update location internally (called by delegate)
    func updateLocation(_ location: CLLocation) async {
        self.currentLocation = location
        
        // Notify callback
        if let callback = locationUpdateCallback {
            await callback(location)
        }
    }
}

/// Internal delegate class for CLLocationManager
private class LocationManagerDelegate: NSObject, CLLocationManagerDelegate, @unchecked Sendable {
    private weak var service: LocationTrackingService?
    
    init(service: LocationTrackingService) {
        self.service = service
        super.init()
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        Task { [weak self] in
            await self?.service?.updateLocation(location)
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            let locationError: LocationError
            
            if let clError = error as? CLError {
                switch clError.code {
                case .denied:
                    locationError = .permissionDenied
                case .locationUnknown:
                    locationError = .locationUnavailable
                case .network:
                    locationError = .timeout
                default:
                    locationError = .locationUnavailable
                }
            } else {
                locationError = .locationUnavailable
            }
            
            await MainActor.run {
                ErrorHandlingService.shared.handleLocationError(locationError)
            }
        }
    }
    
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        
        #if os(iOS)
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            Task { [weak self] in
                await self?.service?.startUpdatingLocation()
            }
        }
        #elseif os(macOS)
        if status == .authorizedAlways {
            Task { [weak self] in
                await self?.service?.startUpdatingLocation()
            }
        }
        #endif
    }
}