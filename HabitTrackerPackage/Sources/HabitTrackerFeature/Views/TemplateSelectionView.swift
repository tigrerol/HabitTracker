import SwiftUI

/// View for selecting a morning routine template
public struct TemplateSelectionView: View {
    @Environment(RoutineService.self) private var routineService
    @State private var selectedTemplate: RoutineTemplate?
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                headerView
                
                templatesList
                
                Spacer()
                
                startButton
            }
            .padding()
            .navigationTitle(String(localized: "TemplateSelectionView.NavigationTitle", bundle: .module))
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear {
            // Pre-select default or last used template
            selectedTemplate = routineService.defaultTemplate ?? routineService.lastUsedTemplate ?? routineService.templates.first
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 8) {
            Text(String(localized: "TemplateSelectionView.ChooseRoutine", bundle: .module))
                .font(.title2)
                .fontWeight(.medium)
            
            Text(String(localized: "TemplateSelectionView.SelectTemplate", bundle: .module))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    
    private var templatesList: some View {
        LazyVStack(spacing: 12) {
            ForEach(routineService.templates) { template in
                TemplateCard(
                    template: template,
                    isSelected: selectedTemplate?.id == template.id
                ) {
                    selectedTemplate = template
                }
            }
        }
    }
    
    private var startButton: some View {
        Button {
            if let selectedTemplate {
                routineService.startSession(with: selectedTemplate)
            }
        } label: {
            HStack {
                Image(systemName: "play.fill")
                Text(String(localized: "TemplateSelectionView.StartRoutine", bundle: .module))
            }
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                selectedTemplate?.swiftUIColor ?? .blue,
                in: RoundedRectangle(cornerRadius: 12)
            )
        }
        .disabled(selectedTemplate == nil)
    }
}

/// Card view for displaying a routine template
private struct TemplateCard: View {
    let template: RoutineTemplate
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(template.name)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        
                        Spacer()
                        
                        if template.isDefault {
                            Text(String(localized: "TemplateSelectionView.Default", bundle: .module))
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.blue, in: Capsule())
                        }
                    }
                    
                    if let description = template.description {
                        Text(description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Label(String(format: String(localized: "TemplateSelectionView.HabitsCount", bundle: .module), template.activeHabitsCount), systemImage: "list.bullet")
                        
                        Spacer()
                        
                        Label(template.formattedDuration, systemImage: "clock")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? template.swiftUIColor : .secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.regularMaterial)
                    .stroke(
                        isSelected ? template.swiftUIColor : Color.clear,
                        lineWidth: 2
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    TemplateSelectionView()
        .environment(RoutineService())
}