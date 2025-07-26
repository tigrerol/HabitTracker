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
    
    private var locationManager: LocationManager {
        routineService.smartSelector.locationManager
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Teach the app your important locations to automatically select the best routine based on where you are.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Section("Built-in Locations") {
                    ForEach(LocationType.allCases.filter { $0 != .unknown }, id: \.self) { locationType in
                        LocationRow(
                            locationType: locationType,
                            savedLocation: locationManager.savedLocations[locationType],
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
                
                Section("Custom Locations") {
                    ForEach(locationManager.allCustomLocations) { customLocation in
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
                        Label("Add Custom Location", systemImage: "plus")
                            .foregroundStyle(.blue)
                    }
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("How it works:")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("• Go to each location (home, office, etc.)")
                            Text("• Tap 'Set Current Location' for that place")
                            Text("• The app will detect when you're within 150m")
                            Text("• Your location data stays private on your device")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Privacy & How It Works")
                }
            }
            .navigationTitle("Location Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
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
                    _ = locationManager.createCustomLocation(name: customLocation.name, icon: customLocation.icon)
                }
                editingCustomLocation = nil
            }
        }
        .alert("Delete Location", isPresented: $showingCustomDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let customLocation = customLocationToDelete {
                    locationManager.deleteCustomLocation(id: customLocation.id)
                }
            }
        } message: {
            if let customLocation = customLocationToDelete {
                Text("Are you sure you want to delete \"\(customLocation.name)\"? This action cannot be undone.")
            }
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
                        Text("Set \(savedLocation.dateCreated.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Not set")
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
                Button("Change", action: onAdd)
                    .font(.caption)
                    .foregroundStyle(.blue)
                
                Button("Remove", action: onRemove)
                    .font(.caption)
                    .foregroundStyle(.red)
            } else {
                Button("Set Current Location", action: onAdd)
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
                        Text("Set \(customLocation.dateCreated.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Not set")
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
                    Button("Change", action: onSetLocation)
                        .font(.caption)
                        .foregroundStyle(.blue)
                } else {
                    Button("Set Location", action: onSetLocation)
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
                
                Button("Edit", action: onEdit)
                    .font(.caption)
                    .foregroundStyle(.orange)
                
                Button("Delete", action: onDelete)
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
    
    private var locationManager: LocationManager {
        routineService.smartSelector.locationManager
    }
    
    private var customLocation: CustomLocation? {
        locationManager.getCustomLocation(id: customLocationId)
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
                        
                        Text("Set \(customLocation.name) Location")
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                    
                    if isLoading {
                        VStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(1.2)
                            
                            Text("Getting your current location...")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } else if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    } else if let location = currentLocation {
                        VStack(spacing: 12) {
                            Text("✓ Location found!")
                                .font(.headline)
                                .foregroundStyle(.green)
                            
                            if let customLocation = customLocation {
                                Text("This will set your \(customLocation.name.lowercased()) location to your current position.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            
                            Text("The app will detect when you're within 150 meters of this spot.")
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
                            Text("Save This Location")
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
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            getCurrentLocation()
        }
    }
    
    private func getCurrentLocation() {
        Task {
            await locationManager.startUpdatingLocation()
            
            try? await Task.sleep(for: .seconds(2))
            
            await MainActor.run {
                if let location = locationManager.currentLocation {
                    self.currentLocation = location
                    self.isLoading = false
                } else {
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
    
    private var locationManager: LocationManager {
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
                    
                    Text("Set \(locationType.displayName) Location")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    if isLoading {
                        VStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(1.2)
                            
                            Text("Getting your current location...")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } else if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    } else if let location = currentLocation {
                        VStack(spacing: 12) {
                            Text("✓ Location found!")
                                .font(.headline)
                                .foregroundStyle(.green)
                            
                            Text("This will set your \(locationType.displayName.lowercased()) location to your current position.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                            
                            Text("The app will detect when you're within 150 meters of this spot.")
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
                            Text("Save This Location")
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
            .navigationBarTitleDisplayMode(.inline)
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
            
            await MainActor.run {
                if let location = locationManager.currentLocation {
                    self.currentLocation = location
                    self.isLoading = false
                } else {
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