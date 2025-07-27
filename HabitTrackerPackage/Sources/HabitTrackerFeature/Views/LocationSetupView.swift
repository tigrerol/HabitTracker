import SwiftUI
import CoreLocation

/// View for setting up and managing saved locations
struct LocationSetupView: View {
    @Environment(RoutineService.self) private var routineService
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingLocationPicker = false
    @State private var selectedLocationType: LocationType?
    @State private var showingDeleteAlert = false
    @State private var locationToDelete: LocationType?
    @State private var showingCustomLocationEditor = false
    @State private var editingCustomLocation: CustomLocation?
    @State private var showingCustomDeleteAlert = false
    @State private var customLocationToDelete: CustomLocation?
    @State private var showingCustomLocationPicker = false
    @State private var selectedCustomLocationId: UUID?
    @State private var customLocations: [CustomLocation] = []
    @State private var savedLocations: [LocationType: SavedLocation] = [:]
    
    private var locationManager: LocationManagerAdapter {
        routineService.smartSelector.locationManager
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
                                selectedLocationType = locationType
                                showingLocationPicker = true
                            },
                            onRemove: {
                                locationToDelete = locationType
                                showingDeleteAlert = true
                            }
                        )
                    }
                }
                
                Section(String(localized: "LocationSetupView.CustomLocations.Title", bundle: .module)) {
                    ForEach(customLocations) { customLocation in
                        CustomLocationRow(
                            customLocation: customLocation,
                            onSetLocation: {
                                selectedCustomLocationId = customLocation.id
                                showingCustomLocationPicker = true
                            },
                            onEdit: {
                                editingCustomLocation = customLocation
                                showingCustomLocationEditor = true
                            },
                            onDelete: {
                                customLocationToDelete = customLocation
                                showingCustomDeleteAlert = true
                            }
                        )
                    }
                    
                    Button {
                        editingCustomLocation = nil
                        showingCustomLocationEditor = true
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
        .sheet(isPresented: $showingLocationPicker) {
            if let locationType = selectedLocationType {
                LocationPickerView(locationType: locationType) { location in
                    locationManager.saveLocation(location, as: locationType)
                    selectedLocationType = nil
                }
            }
        }
        .sheet(isPresented: $showingCustomLocationPicker) {
            if let customLocationId = selectedCustomLocationId {
                CustomLocationPickerView(customLocationId: customLocationId) { location in
                    locationManager.setCustomLocationCoordinates(for: customLocationId, location: location)
                    selectedCustomLocationId = nil
                }
            }
        }
        .sheet(isPresented: $showingCustomLocationEditor) {
            CustomLocationEditorView(customLocation: editingCustomLocation) { customLocation in
                if editingCustomLocation != nil {
                    locationManager.updateCustomLocation(customLocation)
                } else {
                    Task {
                        _ = await locationManager.createCustomLocation(name: customLocation.name, icon: customLocation.icon)
                    }
                }
                editingCustomLocation = nil
            }
        }
        .alert(String(localized: "LocationSetupView.DeleteAlert.Title", bundle: .module), isPresented: $showingCustomDeleteAlert) {
            Button(String(localized: "LocationSetupView.DeleteAlert.Cancel", bundle: .module), role: .cancel) { }
            Button(String(localized: "LocationSetupView.DeleteAlert.Delete", bundle: .module), role: .destructive) {
                if let customLocation = customLocationToDelete {
                    locationManager.deleteCustomLocation(id: customLocation.id)
                }
            }
        } message: {
            if let customLocation = customLocationToDelete {
                Text(String(localized: "LocationSetupView.DeleteAlert.Message", bundle: .module).replacingOccurrences(of: "%@", with: customLocation.name))
            }
        }
        .task {
            customLocations = await locationManager.allCustomLocations
            savedLocations = await locationManager.savedLocations
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
    
    private var locationManager: LocationManagerAdapter {
        routineService.smartSelector.locationManager
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
            await locationManager.startUpdatingLocation()
            
            try? await Task.sleep(for: .seconds(2))
            
            if let location = await locationManager.getCurrentLocation() {
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
    
    private var locationManager: LocationManagerAdapter {
        routineService.smartSelector.locationManager
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
            await locationManager.startUpdatingLocation()
            
            // Wait a moment for location to be acquired
            try? await Task.sleep(for: .seconds(2))
            
            if let location = await locationManager.getCurrentLocation() {
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