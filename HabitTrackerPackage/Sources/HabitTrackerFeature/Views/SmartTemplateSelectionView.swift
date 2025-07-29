import SwiftUI

/// Smart template selection with quick start and template switching
struct SmartTemplateSelectionView: View {
    @Environment(RoutineService.self) private var routineService
    @State private var selectedTemplate: RoutineTemplate?
    @State private var selectionReason: String = ""
    @State private var showAllTemplates = false
    @State private var showingRoutineBuilder = false
    @State private var editingTemplate: RoutineTemplate?
    @State private var templateToDelete: RoutineTemplate?
    @State private var showingDeleteAlert = false
    @State private var showingLocationSetup = false
    @State private var showingContextSettings = false
    
    private var timeBasedGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        
        switch hour {
        case 5..<12:
            return String(localized: "SmartTemplateSelectionView.NavigationTitle.Morning", bundle: .module)
        case 12..<17:
            return String(localized: "SmartTemplateSelectionView.NavigationTitle.Afternoon", bundle: .module)
        case 17..<22:
            return String(localized: "SmartTemplateSelectionView.NavigationTitle.Evening", bundle: .module)
        default:
            return String(localized: "SmartTemplateSelectionView.NavigationTitle.Default", bundle: .module)
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                headerView
                
                if let quickStartTemplate = selectedTemplate {
                    quickStartSection(quickStartTemplate)
                }
                
                templateSwitcher
                
                if showAllTemplates {
                    allTemplatesSection
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle(timeBasedGreeting)
            
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        showingContextSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        showingRoutineBuilder = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                buildVersionView
            }
        }
        .onAppear {
            selectSmartTemplate()
        }
        .sheet(isPresented: $showingRoutineBuilder) {
            RoutineBuilderView()
        }
        .sheet(item: $editingTemplate) { template in
            RoutineBuilderView(editingTemplate: template)
        }
        .onChange(of: routineService.templates.count) {
            // Re-select smart template when templates are added/removed
            selectSmartTemplate()
        }
        .onChange(of: routineService.templates) {
            // Re-select smart template when templates are modified
            selectSmartTemplate()
        }
        .onReceive(routineService.routineSelector.locationCoordinator.$currentLocationType) { newType in
            // Force UI refresh when location type changes
            print("🗺️ SmartTemplateView: Location type changed to \(newType), forcing selectSmartTemplate")
            selectSmartTemplate()
        }
        .onReceive(routineService.routineSelector.locationCoordinator.$currentLocation) { location in
            // Force UI refresh when location coordinates change
            print("🗺️ SmartTemplateView: Location coordinates changed, has location: \(location != nil)")
        }
        // Add explicit observation of the RoutineSelector's context changes
        .onChange(of: routineService.routineSelector.currentContext.location) { oldValue, newValue in
            print("🗺️ SmartTemplateView: Context location changed from \(oldValue) to \(newValue)")
            // Force template re-selection when location context changes
            selectSmartTemplate()
        }
        .sheet(isPresented: $showingLocationSetup) {
            LocationSetupView()
        }
        .sheet(isPresented: $showingContextSettings) {
            ContextSettingsView()
        }
        .alert(String(localized: "SmartTemplateSelectionView.DeleteAlert.Title", bundle: .module), isPresented: $showingDeleteAlert) {
            Button(String(localized: "SmartTemplateSelectionView.DeleteAlert.Cancel", bundle: .module), role: .cancel) { }
            Button(String(localized: "SmartTemplateSelectionView.DeleteAlert.Delete", bundle: .module), role: .destructive) {
                if let template = templateToDelete {
                    routineService.deleteTemplate(withId: template.id)
                    // Update selected template if it was deleted
                    if selectedTemplate?.id == template.id {
                        selectSmartTemplate()
                    }
                }
            }
        } message: {
            if let template = templateToDelete {
                Text(String(localized: "SmartTemplateSelectionView.DeleteAlert.Message", bundle: .module).replacingOccurrences(of: "%@", with: template.name))
            }
        }
    }
    
    private var buildVersionView: some View {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        
        let _ = print("📱 App Version Info - Version: \(version), Build: \(build)")
        
        return Text(String(format: String(localized: "SmartTemplateSelectionView.BuildNumber", bundle: .module), version, build))
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.bottom, 8)
    }
    
    private var headerView: some View {
        VStack(spacing: 8) {
            contextIndicatorView
                .padding(.bottom, 8)
            
            Text(String(localized: "SmartTemplateSelectionView.ReadyToStart", bundle: .module))
                .font(.title2)
                .fontWeight(.medium)
            
            if !selectionReason.isEmpty {
                Text(selectionReason)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Text(String(localized: "SmartTemplateSelectionView.TapQuickStart", bundle: .module))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var contextIndicatorView: some View {
        // Force reactivity by accessing the selector directly in the view
        let selector = routineService.routineSelector
        let context = selector.currentContext
        let coordinator = selector.locationCoordinator
        
        // Debug logging for location state
        let _ = print("🗺️ SmartTemplateView contextIndicatorView Debug:")
        let _ = print("   - currentContext.location: \(context.location)")
        let _ = print("   - locationCoordinator.currentLocationType: \(coordinator.currentLocationType)")
        let _ = print("   - locationCoordinator.currentExtendedLocationType: \(coordinator.currentExtendedLocationType)")
        let _ = print("   - locationCoordinator.currentLocation != nil: \(coordinator.currentLocation != nil)")
        
        return HStack(spacing: 16) {
            // Time indicator
            Label {
                Text(context.timeSlot.displayName)
            } icon: {
                Image(systemName: context.timeSlot.icon)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            
            // Day indicator
            Label {
                Text(context.dayCategory.displayName)
            } icon: {
                Image(systemName: context.dayCategory.icon)
                    .foregroundStyle(context.dayCategory.color)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            
            // Location indicator - show actual location name when available
            if context.location != .unknown {
                // Show the actual detected location (Home, Office, etc.)
                Label {
                    Text(context.location.displayName)
                } icon: {
                    Image(systemName: context.location.icon)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            } else if coordinator.currentLocation != nil {
                // Show that location is detected but not categorized as Home/Office
                Label {
                    Text("Current Location")
                } icon: {
                    Image(systemName: "location")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            } else {
                // Location setup button when no location data is available
                Button {
                    showingLocationSetup = true
                } label: {
                    Label {
                        Text(String(localized: "SmartTemplateSelectionView.SetLocations", bundle: .module))
                    } icon: {
                        Image(systemName: "location.circle")
                    }
                    .font(.caption)
                    .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(.regularMaterial)
        )
    }
    
    private func quickStartSection(_ template: RoutineTemplate) -> some View {
        List {
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(localized: "SmartTemplateSelectionView.QuickStart", bundle: .module))
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                        
                        Text(template.name)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(template.swiftUIColor)
                }
                
                HStack {
                    Label(String(format: String(localized: "SmartTemplateSelectionView.HabitsCount", bundle: .module), template.activeHabitsCount), systemImage: "list.bullet")
                    
                    Spacer()
                    
                    Label(template.formattedDuration, systemImage: "clock")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.regularMaterial)
                    .stroke(template.swiftUIColor.opacity(0.3), lineWidth: 1)
            )
            .contentShape(Rectangle())
            .onTapGesture {
                startRoutine(with: template)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive) {
                    templateToDelete = template
                    showingDeleteAlert = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                Button {
                    editingTemplate = template
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                .tint(.orange)
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets())
        }
        .listStyle(.plain)
        .frame(height: 120) // Fixed height for the quick start card
        .scrollDisabled(true)
    }
    
    private var templateSwitcher: some View {
        VStack(spacing: 12) {
            Button {
                withAnimation(.easeInOut) {
                    showAllTemplates.toggle()
                }
            } label: {
                HStack {
                    Text(showAllTemplates ? String(localized: "SmartTemplateSelectionView.HideOptions", bundle: .module) : String(localized: "SmartTemplateSelectionView.ChangeRoutine", bundle: .module))
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Image(systemName: showAllTemplates ? "chevron.up" : "chevron.down")
                        .font(.caption)
                }
                .foregroundStyle(.blue)
                .padding(.horizontal, 4)
            }
            .buttonStyle(.plain)
        }
    }
    
    private var allTemplatesSection: some View {
        List {
            ForEach(routineService.templates) { template in
                CompactTemplateCard(
                    template: template,
                    isSelected: selectedTemplate?.id == template.id,
                    onTap: {
                        selectedTemplate = template
                        startRoutine(with: template)
                    },
                    onEdit: {
                        editingTemplate = template
                    },
                    onDelete: {
                        templateToDelete = template
                        showingDeleteAlert = true
                    }
                )
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
            }
        }
        .listStyle(.plain)
        .frame(height: max(60, CGFloat(routineService.templates.count) * 60)) // Approximate height per row, minimum 60
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }
    
    private func selectSmartTemplate() {
        Task { @MainActor in
            // Use smart selection based on context
            let smartSelection = await routineService.getSmartTemplate()
            selectedTemplate = smartSelection.template
            selectionReason = smartSelection.reason
            
            // Fallback to default logic if smart selection fails
            if selectedTemplate == nil {
                selectedTemplate = routineService.defaultTemplate 
                                ?? routineService.lastUsedTemplate 
                                ?? routineService.templates.first
                selectionReason = ""
            }
        }
    }
    
    private func startRoutine(with template: RoutineTemplate) {
        do {
            try routineService.startSession(with: template)
        } catch {
            // Handle error - could show an alert or log the error
            LoggingService.shared.error("Failed to start routine session", category: .routine, metadata: ["error": error.localizedDescription, "template": template.name])
        }
    }
}

/// Compact template card for quick selection
private struct CompactTemplateCard: View {
    let template: RoutineTemplate
    let isSelected: Bool
    let onTap: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(template.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                
                Text("\(String(format: String(localized: "SmartTemplateSelectionView.HabitsCount", bundle: .module), template.activeHabitsCount)) • \(template.formattedDuration)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "play.circle.fill")
                .font(.title2)
                .foregroundStyle(template.swiftUIColor)
            
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.regularMaterial)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button {
                onEdit()
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.orange)
        }
    }
}

#Preview {
    SmartTemplateSelectionView()
        .environment(RoutineService())
}