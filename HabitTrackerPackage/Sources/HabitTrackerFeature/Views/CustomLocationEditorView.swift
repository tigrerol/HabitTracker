import SwiftUI

/// View for creating and editing custom locations
struct CustomLocationEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(RoutineService.self) private var routineService
    
    let customLocation: CustomLocation?
    let onSave: (CustomLocation) -> Void
    
    @State private var name: String = ""
    @State private var selectedIcon: String = "location.fill"
    @State private var showingIconPicker = false
    
    private var isEditing: Bool {
        customLocation != nil
    }
    
    private var locationManager: LocationManager {
        routineService.smartSelector.locationManager
    }
    
    init(customLocation: CustomLocation? = nil, onSave: @escaping (CustomLocation) -> Void) {
        self.customLocation = customLocation
        self.onSave = onSave
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(String(localized: "CustomLocationEditorView.LocationName.Placeholder", bundle: .module), text: $name)
                        .textInputAutocapitalization(.words)
                    
                    HStack {
                        Text(String(localized: "CustomLocationEditorView.Icon.Label", bundle: .module))
                        Spacer()
                        Button {
                            showingIconPicker = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: selectedIcon)
                                    .foregroundStyle(.blue)
                                Text(String(localized: "CustomLocationEditorView.Icon.Choose", bundle: .module))
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                } header: {
                    Text(String(localized: "CustomLocationEditorView.LocationDetails.Section", bundle: .module))
                } footer: {
                    Text(String(localized: "CustomLocationEditorView.LocationDetails.Footer", bundle: .module))
                }
            }
            .navigationTitle(isEditing ? String(localized: "CustomLocationEditorView.EditLocation.NavigationTitle", bundle: .module) : String(localized: "CustomLocationEditorView.NewLocation.NavigationTitle", bundle: .module))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "CustomLocationEditorView.Cancel", bundle: .module)) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "CustomLocationEditorView.Save", bundle: .module)) {
                        saveLocation()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .sheet(isPresented: $showingIconPicker) {
            IconPickerView(selectedIcon: $selectedIcon)
        }
        .onAppear {
            loadExistingData()
        }
    }
    
    private func loadExistingData() {
        if let customLocation = customLocation {
            name = customLocation.name
            selectedIcon = customLocation.icon
        }
    }
    
    private func saveLocation() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        if let existingLocation = customLocation {
            // Update existing location
            var updatedLocation = existingLocation
            updatedLocation.name = trimmedName
            updatedLocation.icon = selectedIcon
            onSave(updatedLocation)
        } else {
            // Create new location
            let newLocation = CustomLocation(
                name: trimmedName,
                icon: selectedIcon
            )
            onSave(newLocation)
        }
        
        dismiss()
    }
}

/// Icon picker for custom locations
private struct IconPickerView: View {
    @Binding var selectedIcon: String
    @Environment(\.dismiss) private var dismiss
    
    private let locationIcons = [
        "location.fill", "house.fill", "building.2.fill", "figure.strengthtraining.traditional",
        "airplane", "car.fill", "tram.fill", "bus.fill",
        "cup.and.saucer.fill", "fork.knife", "cart.fill", "bag.fill",
        "book.fill", "graduationcap.fill", "cross.fill", "heart.fill",
        "star.fill", "flag.fill", "pin.fill", "mappin.and.ellipse"
    ]
    
    var body: some View {
        NavigationStack {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 20) {
                ForEach(locationIcons, id: \.self) { icon in
                    Button {
                        selectedIcon = icon
                        dismiss()
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: icon)
                                .font(.system(size: 24))
                                .foregroundStyle(selectedIcon == icon ? .white : .blue)
                                .frame(width: 50, height: 50)
                                .background(
                                    Circle()
                                        .fill(selectedIcon == icon ? .blue : .clear)
                                        .stroke(.blue, lineWidth: selectedIcon == icon ? 0 : 1)
                                )
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .navigationTitle(String(localized: "CustomLocationEditorView.ChooseIcon.NavigationTitle", bundle: .module))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "CustomLocationEditorView.Cancel", bundle: .module)) {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    CustomLocationEditorView { _ in }
        .environment(RoutineService())
}