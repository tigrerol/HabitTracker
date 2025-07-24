import SwiftUI

/// Smart template selection with quick start and template switching
struct SmartTemplateSelectionView: View {
    @Environment(RoutineService.self) private var routineService
    @State private var selectedTemplate: RoutineTemplate?
    @State private var showAllTemplates = false
    @State private var showingRoutineBuilder = false
    
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
    }
    
    private var headerView: some View {
        VStack(spacing: 8) {
            Text("Ready to start?")
                .font(.title2)
                .fontWeight(.medium)
            
            Text("Tap Quick Start or choose a different routine")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
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
                        
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(template.swiftUIColor)
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
                    isSelected: selectedTemplate?.id == template.id
                ) {
                    selectedTemplate = template
                    startRoutine(with: template)
                }
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }
    
    private func selectSmartTemplate() {
        // Smart selection logic: Default > Recently Used > First
        selectedTemplate = routineService.defaultTemplate 
                        ?? routineService.lastUsedTemplate 
                        ?? routineService.templates.first
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
                
                Image(systemName: "play.circle.fill")
                    .foregroundStyle(template.swiftUIColor)
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