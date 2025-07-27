import SwiftUI
import CoreLocation
import Combine

/// Centralized error recovery handlers for common error scenarios
@MainActor
public final class ErrorRecoveryHandlers {
    
    // MARK: - Location Error Recovery
    
    /// Handle location permission denied errors
    public static func handleLocationPermissionDenied() async {
        let recoveryActions = [
            ErrorPresentationService.RecoveryActionButton(
                action: .enableLocation,
                label: "Open Settings",
                style: .primary,
                handler: {
                    await openLocationSettings()
                }
            ),
            ErrorPresentationService.RecoveryActionButton(
                action: .ignore,
                label: "Continue Without Location",
                style: .secondary,
                handler: {
                    await LocationService().stopUpdatingLocation()
                }
            )
        ]
        
        ErrorPresentationService.shared.present(
            LocationError.permissionDenied,
            style: .sheet,
            customRecoveryActions: recoveryActions
        )
    }
    
    /// Handle location unavailable errors
    public static func handleLocationUnavailable() async {
        let recoveryActions = [
            ErrorPresentationService.RecoveryActionButton(
                action: .retry,
                label: "Try Again",
                style: .primary,
                handler: {
                    await LocationService().startUpdatingLocation()
                }
            ),
            ErrorPresentationService.RecoveryActionButton(
                action: .checkSettings,
                label: "Check Location Settings",
                style: .secondary,
                handler: {
                    await openLocationSettings()
                }
            )
        ]
        
        ErrorPresentationService.shared.present(
            LocationError.locationUnavailable,
            style: .banner,
            customRecoveryActions: recoveryActions
        )
    }
    
    // MARK: - Network Error Recovery
    
    /// Handle network connectivity errors
    public static func handleNetworkError(_ error: NetworkError) async {
        let recoveryActions = [
            ErrorPresentationService.RecoveryActionButton(
                action: .retry,
                label: "Retry",
                style: .primary,
                handler: {
                    // Retry logic would be implemented by the calling code
                    LoggingService.shared.info("User requested network retry", category: .network)
                }
            ),
            ErrorPresentationService.RecoveryActionButton(
                action: .checkInternet,
                label: "Check Wi-Fi",
                style: .secondary,
                handler: {
                    await openWifiSettings()
                }
            )
        ]
        
        ErrorPresentationService.shared.present(
            error,
            style: error.severity == .high ? .alert : .snackbar,
            customRecoveryActions: recoveryActions
        )
    }
    
    // MARK: - Data Error Recovery
    
    /// Handle data corruption errors
    public static func handleDataCorruption(_ error: DataError) async {
        let recoveryActions = [
            ErrorPresentationService.RecoveryActionButton(
                action: .restart,
                label: "Reset Data",
                style: .destructive,
                handler: {
                    await resetCorruptedData()
                }
            ),
            ErrorPresentationService.RecoveryActionButton(
                action: .contact,
                label: "Report Issue",
                style: .secondary,
                handler: {
                    await openSupportEmail(subject: "Data Corruption", error: error)
                }
            )
        ]
        
        ErrorPresentationService.shared.present(
            error,
            style: .alert,
            customRecoveryActions: recoveryActions
        )
    }
    
    // MARK: - Validation Error Recovery
    
    /// Handle validation errors with inline fixes
    public static func handleValidationError(_ error: ValidationError, fixAction: (() async -> Void)? = nil) async {
        var recoveryActions = [ErrorPresentationService.RecoveryActionButton]()
        
        if let fixAction = fixAction {
            recoveryActions.append(
                ErrorPresentationService.RecoveryActionButton(
                    action: .retry,
                    label: "Fix & Continue",
                    style: .primary,
                    handler: fixAction
                )
            )
        }
        
        recoveryActions.append(
            ErrorPresentationService.RecoveryActionButton(
                action: .ignore,
                label: "Cancel",
                style: .secondary
            )
        )
        
        ErrorPresentationService.shared.present(
            error,
            style: .banner,
            customRecoveryActions: recoveryActions
        )
    }
    
    // MARK: - Routine Error Recovery
    
    /// Handle routine session errors
    public static func handleRoutineError(_ error: RoutineError, routineService: RoutineService) async {
        switch error {
        case .noActiveSession:
            let recoveryActions = [
                ErrorPresentationService.RecoveryActionButton(
                    action: .retry,
                    label: "Start New Session",
                    style: .primary,
                    handler: {
                        // Start a new session with the last used template
                        if let lastTemplate = routineService.templates.first {
                            try? routineService.startSession(with: lastTemplate)
                        }
                    }
                )
            ]
            
            ErrorPresentationService.shared.present(
                error,
                style: .banner,
                customRecoveryActions: recoveryActions
            )
            
        case .habitNotFound:
            // For missing habits, offer to refresh the session
            let recoveryActions = [
                ErrorPresentationService.RecoveryActionButton(
                    action: .retry,
                    label: "Refresh Session",
                    style: .primary,
                    handler: {
                        // Implementation would refresh the current session
                        LoggingService.shared.info("Refreshing routine session", category: .routine)
                    }
                )
            ]
            
            ErrorPresentationService.shared.present(
                error,
                style: .snackbar,
                customRecoveryActions: recoveryActions
            )
            
        default:
            // Use default recovery actions
            ErrorPresentationService.shared.present(error)
        }
    }
    
    // MARK: - Helper Methods
    
    public static func openLocationSettings() async {
        #if canImport(UIKit)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            await UIApplication.shared.open(url)
        }
        #endif
    }
    
    private static func openWifiSettings() async {
        #if canImport(UIKit)
        // On iOS, we can only open general settings
        if let url = URL(string: UIApplication.openSettingsURLString) {
            await UIApplication.shared.open(url)
        }
        #endif
    }
    
    private static func resetCorruptedData() async {
        // This would be implemented based on your data persistence strategy
        LoggingService.shared.warning("Data reset requested due to corruption", category: .data)
        
        // Clear specific corrupted data
        UserDefaults.standard.removeObject(forKey: "SavedLocations")
        UserDefaults.standard.removeObject(forKey: "CustomLocations")
        
        // Notify user of completion
        ErrorPresentationService.shared.present(
            DataError.dataValidationFailed(reason: "Data has been reset. Please restart the app."),
            style: .alert
        )
    }
    
    private static func openSupportEmail(subject: String, error: any HabitTrackerError) async {
        #if canImport(UIKit)
        let body = """
        Error Details:
        Category: \(error.category.rawValue)
        Severity: \(error.severity.rawValue)
        Message: \(error.userMessage)
        Technical: \(error.technicalDetails)
        
        Device Info:
        iOS Version: \(UIDevice.current.systemVersion)
        Device Model: \(UIDevice.current.model)
        App Version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")
        """
        
        let emailURL = "mailto:support@habittracker.app?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&body=\(body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        
        if let url = URL(string: emailURL) {
            await UIApplication.shared.open(url)
        }
        #endif
    }
}

// MARK: - View Extension for Error Recovery

extension View {
    /// Modifier to handle specific error types with custom recovery
    public func handleLocationErrors() -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .init("LocationAuthorizationChanged"))) { _ in
            Task {
                let locationManager = CLLocationManager()
                switch locationManager.authorizationStatus {
                case .denied, .restricted:
                    await ErrorRecoveryHandlers.handleLocationPermissionDenied()
                default:
                    break
                }
            }
        }
    }
    
    /// Generic error handler with custom recovery
    public func handleError<E: HabitTrackerError & Equatable>(
        _ error: Binding<E?>,
        recovery: @escaping (E) async -> Void
    ) -> some View {
        self.onReceive(Just(error.wrappedValue)) { newError in
            if let unwrappedError = newError {
                Task {
                    await recovery(unwrappedError)
                    error.wrappedValue = nil
                }
            }
        }
    }
}

// MARK: - Smart Error Recovery

/// Protocol for views that can provide context-aware error recovery
protocol ErrorRecoverable {
    associatedtype Context
    func suggestRecovery(for error: any HabitTrackerError, context: Context) -> [ErrorPresentationService.RecoveryActionButton]
}

/// Example implementation for location-aware views
struct LocationErrorRecovery: ErrorRecoverable {
    typealias Context = CLLocation?
    
    func suggestRecovery(for error: any HabitTrackerError, context: CLLocation?) -> [ErrorPresentationService.RecoveryActionButton] {
        guard let locationError = error as? LocationError else {
            return []
        }
        
        switch locationError {
        case .permissionDenied:
            return [
                ErrorPresentationService.RecoveryActionButton(
                    action: .enableLocation,
                    label: "Enable Location Services",
                    style: .primary,
                    handler: {
                        await ErrorRecoveryHandlers.openLocationSettings()
                    }
                )
            ]
            
        case .locationUnavailable:
            if context == nil {
                return [
                    ErrorPresentationService.RecoveryActionButton(
                        action: .retry,
                        label: "Try Again",
                        style: .primary,
                        handler: {
                            await LocationService().startUpdatingLocation()
                        }
                    )
                ]
            }
            
        default:
            break
        }
        
        return []
    }
}