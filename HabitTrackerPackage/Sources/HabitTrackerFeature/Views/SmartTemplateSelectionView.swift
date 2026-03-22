import SwiftUI

/// Smart template selection with quick start and template switching
struct SmartTemplateSelectionView: View {
    @Environment(RoutineService.self) private var routineService
    @Environment(ThemeManager.self) private var themeManager
    @State private var selectedTemplate: RoutineTemplate?
    @State private var sortedTemplates: [RoutineTemplate] = []
    @State private var selectionReason: String = ""
    @State private var showingRoutineBuilder = false
    @State private var editingTemplate: RoutineTemplate?
    @State private var templateToDelete: RoutineTemplate?
    @State private var showingDeleteAlert = false
    @State private var showingLocationSetup = false
    @State private var showingContextSettings = false
    @Namespace private var templateTransition
    
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

                allTemplatesSection
            }
            .padding()
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(timeBasedGreeting)
            
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    SettingsButton()
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        showingRoutineBuilder = true
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
                            .foregroundStyle(themeManager.currentAccentColor)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                buildVersionView
            }
        }
        .task(id: selectionTrigger) {
            await selectSmartTemplate()
        }
        .sheet(isPresented: $showingRoutineBuilder) {
            RoutineBuilderView()
        }
        .sheet(item: $editingTemplate) { template in
            RoutineBuilderView(editingTemplate: template)
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
                    // Template count change triggers .task(id: selectionTrigger) automatically
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

        return Text(String(format: String(localized: "SmartTemplateSelectionView.BuildNumber", bundle: .module), version, build))
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.bottom, 8)
    }
    
    private var headerView: some View {
        VStack(spacing: 12) {
            contextIndicatorView
                .padding(.bottom, 8)
            
            if !selectionReason.isEmpty {
                Text(selectionReason)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
    
    private var contextIndicatorView: some View {
        // Force reactivity by accessing the selector directly in the view
        let selector = routineService.routineSelector
        let context = selector.currentContext
        let coordinator = selector.locationCoordinator
        return HStack(spacing: 16) {
            // Time indicator
            Label {
                Text(context.timeSlot.displayName)
            } icon: {
                Image(systemName: context.timeSlot.icon)
                    .foregroundStyle(themeManager.currentAccentColor.opacity(0.8))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            
            // Day indicator
            Label {
                Text(context.dayCategories.map(\.displayName).joined(separator: " + "))
            } icon: {
                Image(systemName: context.dayCategories.first?.icon ?? "calendar")
                    .foregroundStyle(context.dayCategories.first?.color ?? .secondary)
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
                        .foregroundStyle(themeManager.currentAccentColor)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            } else if coordinator.currentLocation != nil {
                // Show that location is detected but not categorized as Home/Office
                Label {
                    Text("Current Location")
                } icon: {
                    Image(systemName: "location")
                        .foregroundStyle(themeManager.currentAccentColor.opacity(0.7))
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
                    .foregroundStyle(themeManager.currentAccentColor)
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
        HStack(spacing: 16) {
            // Left: text content
            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "SmartTemplateSelectionView.QuickStart", bundle: .module))
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(themeManager.currentAccentColor)
                    .tracking(0.5)
                    .textCase(.uppercase)

                Text(template.name)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(.primary)

                HStack(spacing: 10) {
                    Label(
                        String(format: String(localized: "SmartTemplateSelectionView.HabitsCount", bundle: .module), template.activeHabitsCount),
                        systemImage: "list.bullet"
                    )
                    Label(template.formattedDuration, systemImage: "clock")

                    ContextMatchIcons(rule: template.contextRule, context: routineService.routineSelector.currentContext)
                }
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)
            }

            Spacer()

            // Right: play button
            ZStack {
                Circle()
                    .fill(themeManager.currentAccentColor.opacity(0.12))
                    .frame(width: 52, height: 52)

                Image(systemName: "play.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(themeManager.currentAccentColor)
                    .offset(x: 1)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            themeManager.currentAccentColor.opacity(0.4),
                            themeManager.currentAccentColor.opacity(0.15)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .contextMenu {
            Button {
                editingTemplate = template
            } label: {
                Label("Edit Template", systemImage: "pencil")
            }

            Button(role: .destructive) {
                templateToDelete = template
                showingDeleteAlert = true
            } label: {
                Label("Delete Template", systemImage: "trash")
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(AnimationPresets.smoothSpring) {
                startRoutine(with: template)
            }
        }
    }
    
    
    private var allTemplatesSection: some View {
        List {
            // Quick Start Section (only show if there's a selected template)
            if let quickStartTemplate = selectedTemplate {
                quickStartSection(quickStartTemplate)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 16, trailing: 0))
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            templateToDelete = quickStartTemplate
                            showingDeleteAlert = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        Button {
                            editingTemplate = quickStartTemplate
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.orange)
                    }
            }
            
            ForEach(sortedTemplates.filter { $0.id != selectedTemplate?.id }) { template in
                CompactTemplateCard(
                    template: template,
                    isSelected: selectedTemplate?.id == template.id,
                    namespace: templateTransition,
                    onTap: {
                        selectedTemplate = template
                        withAnimation(AnimationPresets.smoothSpring) {
                            startRoutine(with: template)
                        }
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
        .scrollContentBackground(.hidden)
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }
    
    private var selectionTrigger: String {
        let context = routineService.routineSelector.currentContext
        let templateHash = routineService.templates.hashValue
        let location = String(describing: context.location)
        let timeSlot = context.timeSlot.rawValue
        let dayCategories = context.dayCategories.map(\.id).sorted().joined(separator: ",")
        return "\(templateHash)-\(location)-\(timeSlot)-\(dayCategories)"
    }

    private func selectSmartTemplate() async {
        let result = await routineService.getSmartTemplateAndSort()
        sortedTemplates = result.sorted
        selectedTemplate = result.best
        selectionReason = result.reason

        // Fallback to default logic if smart selection fails
        if selectedTemplate == nil {
            selectedTemplate = routineService.defaultTemplate
                            ?? routineService.lastUsedTemplate
                            ?? routineService.templates.first
            selectionReason = ""
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

/// Shows small icons for which context dimensions a routine targets,
/// with matching dimensions highlighted in bold and accent color.
private struct ContextMatchIcons: View {
    let rule: RoutineContextRule?
    let context: RoutineContext

    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        if let rule {
            let timeMatch = !rule.timeSlots.isEmpty && rule.timeSlots.contains(context.timeSlot)
            let dayMatch = !rule.dayCategoryIds.isEmpty && context.dayCategories.contains(where: { rule.dayCategoryIds.contains($0.id) })
            let locationMatch = !rule.locationIds.isEmpty && rule.locationIds.contains(context.location.rawValue)

            HStack(spacing: 4) {
                if !rule.timeSlots.isEmpty {
                    Image(systemName: timeMatch ? "clock.fill" : "clock")
                        .fontWeight(timeMatch ? .bold : .regular)
                        .foregroundStyle(timeMatch ? themeManager.currentAccentColor : .secondary)
                }
                if !rule.dayCategoryIds.isEmpty {
                    Image(systemName: dayMatch ? "calendar.circle.fill" : "calendar")
                        .fontWeight(dayMatch ? .bold : .regular)
                        .foregroundStyle(dayMatch ? themeManager.currentAccentColor : .secondary)
                }
                if !rule.locationIds.isEmpty {
                    Image(systemName: locationMatch ? "location.fill" : "location")
                        .fontWeight(locationMatch ? .bold : .regular)
                        .foregroundStyle(locationMatch ? themeManager.currentAccentColor : .secondary)
                }
            }
            .font(.system(size: 10))
        }
    }
}

/// Compact template card for quick selection
private struct CompactTemplateCard: View {
    let template: RoutineTemplate
    let isSelected: Bool
    let namespace: Namespace.ID
    let onTap: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    @Environment(ThemeManager.self) private var themeManager
    @Environment(RoutineService.self) private var routineService


    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(template.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .matchedGeometry(
                        id: .templateTitle(templateId: template.id),
                        in: namespace,
                        isSource: true
                    )

                HStack(spacing: 6) {
                    Text("\(String(format: String(localized: "SmartTemplateSelectionView.HabitsCount", bundle: .module), template.activeHabitsCount)) • \(template.formattedDuration)")
                    ContextMatchIcons(rule: template.contextRule, context: routineService.routineSelector.currentContext)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "play.circle.fill")
                .font(.title2)
                .foregroundStyle(
                    isSelected ? 
                    LinearGradient(
                        colors: [themeManager.currentAccentColor, themeManager.currentAccentColor.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ) :
                    LinearGradient(
                        colors: [themeManager.currentAccentColor.opacity(0.6), themeManager.currentAccentColor.opacity(0.4)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .matchedGeometry(
                    id: .templatePlayButton(templateId: template.id), 
                    in: namespace,
                    isSource: true
                )
            
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    isSelected ? 
                    LinearGradient(
                        colors: [
                            themeManager.currentAccentColor.opacity(0.1),
                            themeManager.currentAccentColor.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ) :
                    LinearGradient(
                        colors: [Color.clear, Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .background(.regularMaterial)
                .matchedGeometry(
                    id: .templateCard(templateId: template.id), 
                    in: namespace,
                    isSource: true
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    isSelected ? themeManager.currentAccentColor.opacity(0.3) : Color.clear,
                    lineWidth: isSelected ? 1 : 0
                )
        )
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(template.name), \(template.activeHabitsCount) habits, \(template.formattedDuration)\(isSelected ? ", selected" : "")")
        .accessibilityAddTraits(.isButton)
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