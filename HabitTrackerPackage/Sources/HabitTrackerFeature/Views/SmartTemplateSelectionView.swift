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
            .navigationTitle("Good Morning!")
            .navigationBarTitleDisplayMode(.large)
            .safeAreaInset(edge: .bottom) {
                Text("Build: 2024.12.24.1847")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 8)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingRoutineBuilder = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
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
        .alert("Delete Routine", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
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
                Text("Are you sure you want to delete \"\(template.name)\"? This action cannot be undone.")
            }
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 8) {
            contextIndicatorView
                .padding(.bottom, 8)
            
            Text("Ready to start?")
                .font(.title2)
                .fontWeight(.medium)
            
            if !selectionReason.isEmpty {
                Text(selectionReason)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Text("Tap Quick Start or choose a different routine")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var contextIndicatorView: some View {
        HStack(spacing: 16) {
            // Time indicator
            Label {
                Text(routineService.smartSelector.currentContext.timeSlot.displayName)
            } icon: {
                Image(systemName: routineService.smartSelector.currentContext.timeSlot.icon)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            
            // Day indicator
            Label {
                Text(routineService.smartSelector.currentContext.dayType.displayName)
            } icon: {
                Image(systemName: routineService.smartSelector.currentContext.dayType.icon)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            
            // Location indicator (if known)
            if routineService.smartSelector.currentContext.location != .unknown {
                Label {
                    Text(routineService.smartSelector.currentContext.location.displayName)
                } icon: {
                    Image(systemName: routineService.smartSelector.currentContext.location.icon)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
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
                            Text("Quick Start")
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
                        Label("\(template.activeHabitsCount) habits", systemImage: "list.bullet")
                        
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
                    Text(showAllTemplates ? "Hide Options" : "Change Routine")
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
        // Use smart selection based on context
        let smartSelection = routineService.smartTemplate
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
    
    private func startRoutine(with template: RoutineTemplate) {
        routineService.startSession(with: template)
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
                    
                    Text("\(template.activeHabitsCount) habits • \(template.formattedDuration)")
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
                            Label("Edit", systemImage: "pencil")
                        }
                        
                        Button(role: .destructive) {
                            onDelete()
                        } label: {
                            Label("Delete", systemImage: "trash")
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