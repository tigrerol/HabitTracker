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

/// Unified location item type for consistent handling
private enum LocationItem {
    case builtin(LocationType, SavedLocation?)
    case custom(CustomLocation)
    
    var id: String {
        switch self {
        case .builtin(let locationType, _):
            return "builtin_\(locationType.rawValue)"
        case .custom(let customLocation):
            return "custom_\(customLocation.id.uuidString)"
        }
    }
    
    var name: String {
        switch self {
        case .builtin(let locationType, _):
            return locationType.displayName
        case .custom(let customLocation):
            return customLocation.name
        }
    }
    
    var icon: String {
        switch self {
        case .builtin(let locationType, _):
            return locationType.icon
        case .custom(let customLocation):
            return customLocation.icon
        }
    }
    
    var isConfigured: Bool {
        switch self {
        case .builtin(_, let savedLocation):
            return savedLocation != nil
        case .custom(let customLocation):
            return customLocation.hasCoordinates
        }
    }
    
    var dateConfigured: Date? {
        switch self {
        case .builtin(_, let savedLocation):
            return savedLocation?.dateCreated
        case .custom(let customLocation):
            return customLocation.hasCoordinates ? customLocation.dateCreated : nil
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
            
            allLocationsSection
            
            privacySection
        }
    }
    
    private var allLocationsSection: some View {
        Section(String(localized: "LocationSetupView.Locations.Title", bundle: .module)) {
            // Built-in locations
            ForEach(LocationType.allCases.filter { $0 != .unknown }, id: \.self) { locationType in
                UnifiedLocationRow(
                    locationItem: .builtin(locationType, locationState.savedLocations[locationType]),
                    onEdit: {
                        locationState.clearAlert()
                        locationState.setSheet(.locationPicker(locationType))
                    }
                )
            }
            .onDelete { indexSet in
                for index in indexSet {
                    let locationType = LocationType.allCases.filter { $0 != .unknown }[index]
                    locationState.clearSheet()
                    locationState.setAlert(.deleteLocation(locationType))
                }
            }
            
            // Custom locations
            ForEach(locationState.customLocations) { customLocation in
                UnifiedLocationRow(
                    locationItem: .custom(customLocation),
                    onEdit: {
                        locationState.clearAlert()
                        if customLocation.hasCoordinates {
                            locationState.setSheet(.customLocationPicker(customLocation.id))
                        } else {
                            locationState.setSheet(.customLocationPicker(customLocation.id))
                        }
                    },
                    onEditName: {
                        locationState.clearAlert()
                        locationState.setSheet(.customLocationEditor(customLocation))
                    }
                )
            }
            .onDelete { indexSet in
                for index in indexSet {
                    let customLocation = locationState.customLocations[index]
                    locationState.clearSheet()
                    locationState.setAlert(.deleteCustomLocation(customLocation))
                }
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


/// Unified row for both built-in and custom locations
private struct UnifiedLocationRow: View {
    let locationItem: LocationItem
    let onEdit: () -> Void
    let onEditName: (() -> Void)?
    
    init(locationItem: LocationItem, onEdit: @escaping () -> Void, onEditName: (() -> Void)? = nil) {
        self.locationItem = locationItem
        self.onEdit = onEdit
        self.onEditName = onEditName
    }
    
    var body: some View {
        Button(action: onEdit) {
            HStack {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(locationItem.name)
                            .foregroundStyle(.primary)
                        
                        if locationItem.isConfigured {
                            if let date = locationItem.dateConfigured {
                                Text(String(localized: "LocationSetupView.LocationSet.Date", bundle: .module).replacingOccurrences(of: "%@", with: date.formatted(date: .abbreviated, time: .omitted)))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Text(String(localized: "LocationSetupView.LocationSet.NotSet", bundle: .module))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } icon: {
                    Image(systemName: locationItem.icon)
                        .foregroundStyle(.blue)
                }
                
                Spacer()
                
                // Show appropriate action text
                Text(locationItem.isConfigured ? 
                     String(localized: "LocationSetupView.Change.Button", bundle: .module) : 
                     String(localized: "LocationSetupView.SetLocation.Button", bundle: .module))
                    .font(.caption)
                    .foregroundStyle(.blue)
                
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            // Only show edit name/icon for custom locations
            if case .custom = locationItem, let onEditName = onEditName {
                Button {
                    onEditName()
                } label: {
                    Label("Edit Name", systemImage: "pencil")
                }
                .tint(.orange)
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