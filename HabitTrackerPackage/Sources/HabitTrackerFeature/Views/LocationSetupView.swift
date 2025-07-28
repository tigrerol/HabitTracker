import SwiftUI
import CoreLocation

/// Alert item for managing different alert types
private enum AlertItem: Identifiable {
    case deleteLocation(LocationType)
    case deleteCustomLocation(CustomLocation)
    
    var id: String {
        switch self {
        case .deleteLocation(let locationType):
            return "delete_\(locationType.rawValue)"
        case .deleteCustomLocation(let customLocation):
            return "delete_custom_\(customLocation.id.uuidString)"
        }
    }
}

/// Active sheet for managing sheet presentations
private enum ActiveSheet: Identifiable {
    case locationPicker(LocationType)
    case customLocationPicker(UUID)
    case customLocationEditor(CustomLocation?)
    
    var id: String {
        switch self {
        case .locationPicker(let locationType):
            return "location_picker_\(locationType.rawValue)"
        case .customLocationPicker(let customLocationId):
            return "custom_location_picker_\(customLocationId.uuidString)"
        case .customLocationEditor(let customLocation):
            return "custom_location_editor_\(customLocation?.id.uuidString ?? "new")"
        }
    }
}

/// View for setting up and managing saved locations
struct LocationSetupView: View {
    @Environment(RoutineService.self) private var routineService
    @Environment(\.dismiss) private var dismiss
    
    // Single sheet state to prevent presentation conflicts
    @State private var activeSheet: ActiveSheet?
    
    // Combined alert state
    @State private var alertItem: AlertItem?
    @State private var customLocations: [CustomLocation] = []
    @State private var savedLocations: [LocationType: SavedLocation] = [:]
    
    private var locationCoordinator: LocationCoordinator {
        routineService.routineSelector.locationCoordinator
    }
    
    /// Safely present an alert after a brief delay to avoid sheet conflicts
    private func presentAlert(_ alert: AlertItem) {
        // First dismiss any active sheet
        activeSheet = nil
        
        // Wait for sheet dismissal animation to complete before showing alert
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            alertItem = alert
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(String(localized: "LocationSetupView.MainDescription", bundle: .module))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Section(String(localized: "LocationSetupView.BuiltInLocations.Title", bundle: .module)) {
                    ForEach(LocationType.allCases.filter { $0 != .unknown }, id: \.self) { locationType in
                        LocationRow(
                            locationType: locationType,
                            savedLocation: savedLocations[locationType],
                            onAdd: {
                                activeSheet = .locationPicker(locationType)
                            },
                            onRemove: {
                                presentAlert(.deleteLocation(locationType))
                            }
                        )
                    }
                }
                
                Section(String(localized: "LocationSetupView.CustomLocations.Title", bundle: .module)) {
                    ForEach(customLocations) { customLocation in
                        CustomLocationRow(
                            customLocation: customLocation,
                            onSetLocation: {
                                activeSheet = .customLocationPicker(customLocation.id)
                            },
                            onEdit: {
                                activeSheet = .customLocationEditor(customLocation)
                            },
                            onDelete: {
                                presentAlert(.deleteCustomLocation(customLocation))
                            }
                        )
                    }
                    
                    Button {
                        activeSheet = .customLocationEditor(nil)
                    } label: {
                        Label(String(localized: "LocationSetupView.AddCustomLocation.Label", bundle: .module), systemImage: "plus")
                            .foregroundStyle(.blue)
                    }
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(localized: "LocationSetupView.HowItWorks.Title", bundle: .module))
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(String(localized: "LocationSetupView.HowItWorks.Step1", bundle: .module))
                            Text(String(localized: "LocationSetupView.HowItWorks.Step2", bundle: .module))
                            Text(String(localized: "LocationSetupView.HowItWorks.Step3", bundle: .module))
                            Text(String(localized: "LocationSetupView.HowItWorks.Step4", bundle: .module))
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                } header: {
                    Text(String(localized: "LocationSetupView.PrivacyTitle", bundle: .module))
                }
            }
            .navigationTitle(String(localized: "LocationSetupView.NavigationTitle", bundle: .module))
            
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "LocationSetupView.Done.Button", bundle: .module)) {
                        dismiss()
                    }
                }
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .locationPicker(let locationType):
                LocationPickerView(locationType: locationType) { location in
                    Task {
                        try? await locationCoordinator.saveLocation(location, as: locationType)
                        await MainActor.run {
                            savedLocations = locationCoordinator.getSavedLocations()
                        }
                    }
                }
            case .customLocationPicker(let customLocationId):
                CustomLocationPickerView(customLocationId: customLocationId) { location in
                    Task {
                        await locationCoordinator.setCustomLocationCoordinates(for: customLocationId, location: location)
                        await MainActor.run {
                            customLocations = locationCoordinator.getAllCustomLocations()
                        }
                    }
                }
            case .customLocationEditor(let customLocation):
                CustomLocationEditorView(customLocation: customLocation) { updatedCustomLocation in
                    Task {
                        if customLocation != nil {
                            await locationCoordinator.updateCustomLocation(updatedCustomLocation)
                        } else {
                            _ = await locationCoordinator.createCustomLocation(name: updatedCustomLocation.name, icon: updatedCustomLocation.icon)
                        }
                        await MainActor.run {
                            customLocations = locationCoordinator.getAllCustomLocations()
                        }
                    }
                }
            }
        }
        .alert(item: $alertItem) { alertItem in
            switch alertItem {
            case .deleteLocation(let locationType):
                return Alert(
                    title: Text(String(localized: "LocationSetupView.DeleteAlert.Title", bundle: .module)),
                    message: Text(String(localized: "LocationSetupView.DeleteAlert.Message", bundle: .module).replacingOccurrences(of: "%@", with: locationType.displayName)),
                    primaryButton: .destructive(Text(String(localized: "LocationSetupView.DeleteAlert.Delete", bundle: .module))) {
                        Task {
                            await locationCoordinator.removeLocation(for: locationType)
                            await MainActor.run {
                                savedLocations = locationCoordinator.getSavedLocations()
                            }
                        }
                    },
                    secondaryButton: .cancel(Text(String(localized: "LocationSetupView.DeleteAlert.Cancel", bundle: .module)))
                )
            case .deleteCustomLocation(let customLocation):
                return Alert(
                    title: Text(String(localized: "LocationSetupView.DeleteAlert.Title", bundle: .module)),
                    message: Text(String(localized: "LocationSetupView.DeleteAlert.Message", bundle: .module).replacingOccurrences(of: "%@", with: customLocation.name)),
                    primaryButton: .destructive(Text(String(localized: "LocationSetupView.DeleteAlert.Delete", bundle: .module))) {
                        Task {
                            await locationCoordinator.deleteCustomLocation(id: customLocation.id)
                            await MainActor.run {
                                customLocations = locationCoordinator.getAllCustomLocations()
                            }
                        }
                    },
                    secondaryButton: .cancel(Text(String(localized: "LocationSetupView.DeleteAlert.Cancel", bundle: .module)))
                )
            }
        }
        .task {
            customLocations = locationCoordinator.getAllCustomLocations()
            savedLocations = locationCoordinator.getSavedLocations()
        }
    }
}

/// Row showing a location type and its setup status
private struct LocationRow: View {
    let locationType: LocationType
    let savedLocation: SavedLocation?
    let onAdd: () -> Void
    let onRemove: () -> Void
    
    var body: some View {
        HStack {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(locationType.displayName)
                        .foregroundStyle(.primary)
                    
                    if let savedLocation = savedLocation {
                        Text(String(localized: "LocationSetupView.LocationSet.Date", bundle: .module).replacingOccurrences(of: "%@", with: savedLocation.dateCreated.formatted(date: .abbreviated, time: .omitted)))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(String(localized: "LocationSetupView.LocationSet.NotSet", bundle: .module))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } icon: {
                Image(systemName: locationType.icon)
                    .foregroundStyle(.blue)
            }
            
            Spacer()
            
            if savedLocation != nil {
                Button(String(localized: "LocationSetupView.Change.Button", bundle: .module), action: onAdd)
                    .font(.caption)
                    .foregroundStyle(.blue)
                
                Button(String(localized: "LocationSetupView.Remove.Button", bundle: .module), action: onRemove)
                    .font(.caption)
                    .foregroundStyle(.red)
            } else {
                Button(String(localized: "LocationSetupView.SetCurrentLocation.Button", bundle: .module), action: onAdd)
                    .font(.caption)
                    .foregroundStyle(.blue)
            }
        }
    }
}

/// Row showing a custom location and its setup status
private struct CustomLocationRow: View {
    let customLocation: CustomLocation
    let onSetLocation: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(customLocation.name)
                        .foregroundStyle(.primary)
                    
                    if customLocation.hasCoordinates {
                        Text(String(localized: "LocationSetupView.LocationSet.Date", bundle: .module).replacingOccurrences(of: "%@", with: customLocation.dateCreated.formatted(date: .abbreviated, time: .omitted)))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(String(localized: "LocationSetupView.LocationSet.NotSet", bundle: .module))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } icon: {
                Image(systemName: customLocation.icon)
                    .foregroundStyle(.blue)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                if customLocation.hasCoordinates {
                    Button(String(localized: "LocationSetupView.Change.Button", bundle: .module), action: onSetLocation)
                        .font(.caption)
                        .foregroundStyle(.blue)
                } else {
                    Button(String(localized: "LocationSetupView.SetLocation.Button", bundle: .module), action: onSetLocation)
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
                
                Button(String(localized: "LocationSetupView.Edit.Button", bundle: .module), action: onEdit)
                    .font(.caption)
                    .foregroundStyle(.orange)
                
                Button(String(localized: "LocationSetupView.Delete.Button", bundle: .module), action: onDelete)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }
}

/// View for picking the current location for a custom location
private struct CustomLocationPickerView: View {
    let customLocationId: UUID
    let onSave: (CLLocation) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @Environment(RoutineService.self) private var routineService
    
    @State private var isLoading = true
    @State private var currentLocation: CLLocation?
    @State private var errorMessage: String?
    @State private var customLocation: CustomLocation?
    
    private var locationCoordinator: LocationCoordinator {
        routineService.routineSelector.locationCoordinator
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                
                VStack(spacing: 16) {
                    if let customLocation = customLocation {
                        Image(systemName: customLocation.icon)
                            .font(.system(size: 60))
                            .foregroundStyle(.blue)
                        
                        Text(String(localized: "LocationSetupView.SetLocationTitle", bundle: .module).replacingOccurrences(of: "%@", with: customLocation.name))
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                    
                    if isLoading {
                        VStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(1.2)
                            
                            Text(String(localized: "LocationSetupView.GettingLocation", bundle: .module))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } else if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    } else if currentLocation != nil {
                        VStack(spacing: 12) {
                            Text(String(localized: "LocationSetupView.LocationFound", bundle: .module))
                                .font(.headline)
                                .foregroundStyle(.green)
                            
                            if let customLocation = customLocation {
                                Text(String(localized: "LocationSetupView.LocationDescription", bundle: .module).replacingOccurrences(of: "%@", with: customLocation.name.lowercased()))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            
                            Text(String(localized: "LocationSetupView.DetectionRadius", bundle: .module))
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .multilineTextAlignment(.center)
                        }
                    }
                }
                
                Spacer()
                
                VStack(spacing: 12) {
                    if let location = currentLocation {
                        Button {
                            onSave(location)
                            dismiss()
                        } label: {
                            Text(String(localized: "LocationSetupView.SaveThisLocation.Button", bundle: .module))
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(.blue)
                                )
                        }
                    }
                    
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(.secondary)
                }
            }
            .padding()
            .navigationTitle("Set Location")
            
        }
        .onAppear {
            getCurrentLocation()
        }
    }
    
    private func getCurrentLocation() {
        Task {
            await locationCoordinator.startUpdatingLocation()
            
            try? await Task.sleep(for: .seconds(2))
            
            if let location = await locationCoordinator.getCurrentLocation() {
                await MainActor.run {
                    self.currentLocation = location
                    self.isLoading = false
                }
            } else {
                await MainActor.run {
                    self.errorMessage = "Unable to get your current location. Please make sure location services are enabled."
                    self.isLoading = false
                }
            }
        }
    }
}

/// View for picking the current location
private struct LocationPickerView: View {
    let locationType: LocationType
    let onSave: (CLLocation) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @Environment(RoutineService.self) private var routineService
    
    @State private var isLoading = true
    @State private var currentLocation: CLLocation?
    @State private var errorMessage: String?
    
    private var locationCoordinator: LocationCoordinator {
        routineService.routineSelector.locationCoordinator
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                
                VStack(spacing: 16) {
                    Image(systemName: locationType.icon)
                        .font(.system(size: 60))
                        .foregroundStyle(.blue)
                    
                    Text(String(localized: "LocationSetupView.SetLocationTitle", bundle: .module).replacingOccurrences(of: "%@", with: locationType.displayName))
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    if isLoading {
                        VStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(1.2)
                            
                            Text(String(localized: "LocationSetupView.GettingLocation", bundle: .module))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } else if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    } else if currentLocation != nil {
                        VStack(spacing: 12) {
                            Text(String(localized: "LocationSetupView.LocationFound", bundle: .module))
                                .font(.headline)
                                .foregroundStyle(.green)
                            
                            Text(String(localized: "LocationSetupView.LocationDescription", bundle: .module).replacingOccurrences(of: "%@", with: locationType.displayName.lowercased()))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                            
                            Text(String(localized: "LocationSetupView.DetectionRadius", bundle: .module))
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .multilineTextAlignment(.center)
                        }
                    }
                }
                
                Spacer()
                
                VStack(spacing: 12) {
                    if let location = currentLocation {
                        Button {
                            onSave(location)
                            dismiss()
                        } label: {
                            Text(String(localized: "LocationSetupView.SaveThisLocation.Button", bundle: .module))
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(.blue)
                                )
                        }
                    }
                    
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(.secondary)
                }
            }
            .padding()
            .navigationTitle("Set Location")
            
        }
        .onAppear {
            getCurrentLocation()
        }
    }
    
    private func getCurrentLocation() {
        // Request location permission and get current location
        Task {
            await locationCoordinator.startUpdatingLocation()
            
            // Wait a moment for location to be acquired
            try? await Task.sleep(for: .seconds(2))
            
            if let location = await locationCoordinator.getCurrentLocation() {
                await MainActor.run {
                    self.currentLocation = location
                    self.isLoading = false
                }
            } else {
                await MainActor.run {
                    self.errorMessage = "Unable to get your current location. Please make sure location services are enabled."
                    self.isLoading = false
                }
            }
        }
    }
}

#Preview {
    LocationSetupView()
        .environment(RoutineService())
}