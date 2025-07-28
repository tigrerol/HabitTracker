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
            .navigationTitle(String(localized: "SmartTemplateSelectionView.NavigationTitle", bundle: .module))
            
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
        HStack(spacing: 16) {
            // Time indicator
            Label {
                Text(routineService.routineSelector.currentContext.timeSlot.displayName)
            } icon: {
                Image(systemName: routineService.routineSelector.currentContext.timeSlot.icon)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            
            // Day indicator
            Label {
                Text(routineService.routineSelector.currentContext.dayCategory.displayName)
            } icon: {
                Image(systemName: routineService.routineSelector.currentContext.dayCategory.icon)
                    .foregroundStyle(routineService.routineSelector.currentContext.dayCategory.color)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            
            // Location indicator (if known)
            if routineService.routineSelector.currentContext.location != .unknown {
                Label {
                    Text(routineService.routineSelector.currentContext.location.displayName)
                } icon: {
                    Image(systemName: routineService.routineSelector.currentContext.location.icon)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            } else {
                // Location setup button when location is unknown
                Button {
                    showingLocationSetup = true
                } label: {
                    Label {
                        Text(String(localized: "SmartTemplateSelectionView.SetLocations", bundle: .module))
                    } icon: {
                        Image(systemName: "location.badge.plus")
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
        VStack(spacing: 16) {
            // Quick Start Card
            Button {
                startRoutine(with: template)
            } label: {
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
                        
                        HStack(spacing: 8) {
                            Button {
                                editingTemplate = template
                            } label: {
                                Image(systemName: "pencil.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(template.swiftUIColor)
                        }
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
            }
            .buttonStyle(.plain)
        }
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
        LazyVStack(spacing: 8) {
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
            }
            .onDelete { indexSet in
                for index in indexSet {
                    let template = routineService.templates[index]
                    templateToDelete = template
                    showingDeleteAlert = true
                }
            }
        }
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
        Button(action: onTap) {
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
                
                HStack(spacing: 8) {
                    Image(systemName: "play.circle.fill")
                        .foregroundStyle(template.swiftUIColor)
                    
                    Menu {
                        Button {
                            onEdit()
                        } label: {
                            Label(String(localized: "SmartTemplateSelectionView.Edit", bundle: .module), systemImage: "pencil")
                        }
                        
                        Button(role: .destructive) {
                            onDelete()
                        } label: {
                            Label(String(localized: "SmartTemplateSelectionView.Delete", bundle: .module), systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 24, height: 24)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(.regularMaterial)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SmartTemplateSelectionView()
        .environment(RoutineService())
}