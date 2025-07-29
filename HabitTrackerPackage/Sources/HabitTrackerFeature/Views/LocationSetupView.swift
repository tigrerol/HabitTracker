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

/// Isolated state management for location setup to avoid conflicts
@MainActor
@Observable
private final class LocationSetupState {
    var activeSheet: ActiveSheet?
    var alertItem: AlertItem?
    var customLocations: [CustomLocation] = []
    var savedLocations: [LocationType: SavedLocation] = [:]
    
    func clearAlert() {
        alertItem = nil
    }
    
    func clearSheet() {
        activeSheet = nil
    }
    
    func setSheet(_ sheet: ActiveSheet) {
        activeSheet = sheet
    }
    
    func setAlert(_ alert: AlertItem) {
        alertItem = alert
    }
}

/// View for setting up and managing saved locations
struct LocationSetupView: View {
    @Environment(RoutineService.self) private var routineService
    @Environment(\.dismiss) private var dismiss
    
    // Isolated state management
    @State private var locationState = LocationSetupState()
    
    private var locationCoordinator: LocationCoordinator {
        routineService.routineSelector.locationCoordinator
    }
    
    private var contentView: some View {
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
                        savedLocation: locationState.savedLocations[locationType],
                        onAdd: {
                            locationState.setSheet(.locationPicker(locationType))
                        },
                        onRemove: {
                            locationState.clearSheet()
                            locationState.setAlert(.deleteLocation(locationType))
                        }
                    )
                }
            }
            
            customLocationsSection
            
            privacySection
        }
    }
    
    private var customLocationsSection: some View {
        Section(String(localized: "LocationSetupView.CustomLocations.Title", bundle: .module)) {
            ForEach(locationState.customLocations) { customLocation in
                CustomLocationRow(
                    customLocation: customLocation,
                    onSetLocation: {
                        print("🔵 SET LOCATION: Button tapped for \(customLocation.name)")
                        print("🔵 SET LOCATION: Before - activeSheet: \(String(describing: locationState.activeSheet)), alertItem: \(String(describing: locationState.alertItem))")
                        locationState.clearAlert()
                        locationState.setSheet(.customLocationPicker(customLocation.id))
                        print("🔵 SET LOCATION: After - activeSheet: \(String(describing: locationState.activeSheet)), alertItem: \(String(describing: locationState.alertItem))")
                    },
                    onEdit: {
                        print("🟠 EDIT: Button tapped for \(customLocation.name)")
                        print("🟠 EDIT: Before - activeSheet: \(String(describing: locationState.activeSheet)), alertItem: \(String(describing: locationState.alertItem))")
                        locationState.clearAlert()
                        locationState.setSheet(.customLocationEditor(customLocation))
                        print("🟠 EDIT: After - activeSheet: \(String(describing: locationState.activeSheet)), alertItem: \(String(describing: locationState.alertItem))")
                    },
                    onDelete: {
                        print("🔴 DELETE: Button tapped for \(customLocation.name)")
                        print("🔴 DELETE: Before - activeSheet: \(String(describing: locationState.activeSheet)), alertItem: \(String(describing: locationState.alertItem))")
                        locationState.clearSheet()
                        locationState.setAlert(.deleteCustomLocation(customLocation))
                        print("🔴 DELETE: After - activeSheet: \(String(describing: locationState.activeSheet)), alertItem: \(String(describing: locationState.alertItem))")
                    }
                )
            }
            
            Button {
                locationState.setSheet(.customLocationEditor(nil))
            } label: {
                Label(String(localized: "LocationSetupView.AddCustomLocation.Label", bundle: .module), systemImage: "plus")
                    .foregroundStyle(.blue)
            }
        }
    }
    
    private var privacySection: some View {
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
    
    var body: some View {
        NavigationStack {
            contentView
                .navigationTitle(String(localized: "LocationSetupView.NavigationTitle", bundle: .module))
        }
        .sheet(item: $locationState.activeSheet) { sheet in
            switch sheet {
            case .locationPicker(let locationType):
                LocationPickerView(locationType: locationType) { location in
                    Task {
                        try? await locationCoordinator.saveLocation(location, as: locationType)
                        await MainActor.run {
                            locationState.savedLocations = locationCoordinator.getSavedLocations()
                            locationState.clearSheet()
                        }
                    }
                }
            case .customLocationPicker(let customLocationId):
                CustomLocationPickerView(customLocationId: customLocationId) { location in
                    Task {
                        await locationCoordinator.setCustomLocationCoordinates(for: customLocationId, location: location)
                        await MainActor.run {
                            locationState.customLocations = locationCoordinator.getAllCustomLocations()
                            locationState.clearSheet()
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
                            locationState.customLocations = locationCoordinator.getAllCustomLocations()
                            locationState.clearSheet()
                        }
                    }
                }
            }
        }
        .alert(item: $locationState.alertItem) { item in
            switch item {
            case .deleteLocation(let locationType):
                return Alert(
                    title: Text("Delete Location"),
                    message: Text("Are you sure you want to delete \(locationType.displayName)?"),
                    primaryButton: .destructive(Text("Delete")) {
                        Task {
                            await locationCoordinator.removeLocation(for: locationType)
                            await MainActor.run {
                                locationState.savedLocations = locationCoordinator.getSavedLocations()
                                locationState.clearAlert()
                            }
                        }
                    },
                    secondaryButton: .cancel {
                        locationState.clearAlert()
                    }
                )
            case .deleteCustomLocation(let customLocation):
                return Alert(
                    title: Text("Delete Location"),
                    message: Text("Are you sure you want to delete \(customLocation.name)?"),
                    primaryButton: .destructive(Text("Delete")) {
                        Task {
                            await locationCoordinator.deleteCustomLocation(id: customLocation.id)
                            await MainActor.run {
                                locationState.customLocations = locationCoordinator.getAllCustomLocations()
                                locationState.clearAlert()
                            }
                        }
                    },
                    secondaryButton: .cancel {
                        locationState.clearAlert()
                    }
                )
            }
        }
        .task {
            locationState.customLocations = locationCoordinator.getAllCustomLocations()
            locationState.savedLocations = locationCoordinator.getSavedLocations()
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
            .allowsHitTesting(false)
            
            Spacer()
                .allowsHitTesting(false)
            
            VStack {
                HStack(spacing: 12) {
                    if customLocation.hasCoordinates {
                        Button(String(localized: "LocationSetupView.Change.Button", bundle: .module)) {
                            print("🔵 BUTTON: Change button pressed for \(customLocation.name)")
                            onSetLocation()
                            print("🔵 BUTTON: onSetLocation() completed for \(customLocation.name)")
                        }
                        .font(.caption)
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
                        .contentShape(RoundedRectangle(cornerRadius: 6))
                    } else {
                        Button(String(localized: "LocationSetupView.SetLocation.Button", bundle: .module)) {
                            print("🔵 BUTTON: Set Location button pressed for \(customLocation.name)")
                            onSetLocation()
                            print("🔵 BUTTON: onSetLocation() completed for \(customLocation.name)")
                        }
                        .font(.caption)
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
                        .contentShape(RoundedRectangle(cornerRadius: 6))
                    }
                    
                    Button(String(localized: "LocationSetupView.Edit.Button", bundle: .module)) {
                        print("🟠 BUTTON: Edit button pressed for \(customLocation.name)")
                        onEdit()
                        print("🟠 BUTTON: onEdit() completed for \(customLocation.name)")
                    }
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
                    .contentShape(RoundedRectangle(cornerRadius: 6))
                    
                    Button(String(localized: "LocationSetupView.Delete.Button", bundle: .module)) {
                        print("🔴 BUTTON: Delete button pressed for \(customLocation.name)")
                        onDelete()
                        print("🔴 BUTTON: onDelete() completed for \(customLocation.name)")
                    }
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
                    .contentShape(RoundedRectangle(cornerRadius: 6))
                }
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
        .task {
            customLocation = locationCoordinator.getAllCustomLocations().first { $0.id == customLocationId }
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