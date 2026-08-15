import SwiftUI

/// Smart template selection with quick start and template switching
struct SmartTemplateSelectionView: View {
    @Environment(RoutineService.self) private var routineService
    @Environment(ThemeManager.self) private var themeManager
    @Environment(RoutineModeService.self) private var modeService
    @State private var selectedTemplate: RoutineTemplate?
    @State private var sortedTemplates: [RoutineTemplate] = []
    @State private var selectionReason: String = ""
    @State private var showingRoutineBuilder = false
    @State private var editingTemplate: RoutineTemplate?
    @State private var templateToDelete: RoutineTemplate?
    @State private var showingDeleteAlert = false
    @State private var showingLocationSetup = false
    @State private var showingAIImport = false
    @State private var showingModes = false
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
            .appBackground()
            .navigationTitle(timeBasedGreeting)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    SettingsButton()
                }

                ToolbarItem(placement: .confirmationAction) {
                    Menu {
                        Button {
                            showingRoutineBuilder = true
                        } label: {
                            Label("New Routine", systemImage: "plus")
                        }

                        Button {
                            showingAIImport = true
                        } label: {
                            Label("Import from AI", systemImage: "sparkles")
                        }
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
                    }
                    .accessibilityLabel("Add Routine")
                }
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
        .sheet(isPresented: $showingAIImport) {
            AIRoutineImportView()
                .environment(routineService)
        }
        .sheet(isPresented: $showingModes) {
            RoutineModesView()
                .environment(routineService)
                .environment(modeService)
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
                let wrappers = routineService.templatesIncluding(template.id)
                let base = String(localized: "SmartTemplateSelectionView.DeleteAlert.Message", bundle: .module)
                    .replacingOccurrences(of: "%@", with: template.name)
                if wrappers.isEmpty {
                    Text(base)
                } else {
                    Text(base + "\n\nIt's included in \(wrappers.map(\.name).joined(separator: ", ")) — those routines will lose this block.")
                }
            }
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 12) {
            modeChip

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
    
    /// Switcher for routine modes (Vacation, Sick Day, …). Always visible so the
    /// feature is discoverable, but only tinted when a mode is actually on.
    private var modeChip: some View {
        let activeMode = modeService.activeMode
        let selection = Binding<UUID?>(
            get: { modeService.activeModeId },
            set: { newValue in
                if let newValue {
                    modeService.activate(modeId: newValue)
                } else {
                    modeService.deactivate()
                }
            }
        )

        return Menu {
            Picker("Routine Mode", selection: selection) {
                Label("All Routines", systemImage: "square.stack.3d.up")
                    .tag(UUID?.none)

                ForEach(modeService.modes) { mode in
                    Label(mode.name, systemImage: mode.icon)
                        .tag(UUID?.some(mode.id))
                }
            }
            .pickerStyle(.inline)

            Divider()

            Button {
                showingModes = true
            } label: {
                Label("Manage Modes…", systemImage: "slider.horizontal.3")
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: activeMode?.icon ?? "line.3.horizontal.decrease")
                Text(activeMode?.name ?? "All Routines")
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
            }
            .font(.system(.caption, design: .rounded, weight: activeMode == nil ? .regular : .semibold))
            .foregroundStyle(activeMode == nil ? AnyShapeStyle(.secondary) : AnyShapeStyle(themeManager.currentAccentColor))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(activeMode == nil ? AnyShapeStyle(.regularMaterial) : AnyShapeStyle(themeManager.currentAccentColor.opacity(0.15)))
            )
            .overlay(
                Capsule()
                    .stroke(activeMode == nil ? Color.clear : themeManager.currentAccentColor.opacity(0.4), lineWidth: 1)
            )
        }
        .accessibilityLabel(activeMode.map { "Routine mode: \($0.name)" } ?? "Routine mode: all routines")
        .accessibilityHint("Choose which set of routines to show")
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
            if case .custom = context.extendedLocation {
                // Show custom location name
                Label {
                    Text(context.extendedLocation.displayName)
                } icon: {
                    Image(systemName: context.extendedLocation.icon)
                        .foregroundStyle(themeManager.currentAccentColor)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            } else if context.location != .unknown {
                // Show the actual detected location (Home, Office, etc.)
                Label {
                    Text(context.location.displayName)
                } icon: {
                    Image(systemName: context.location.icon)
                        .foregroundStyle(themeManager.currentAccentColor)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            } else if let location = coordinator.currentLocation {
                // Show GPS coordinates when location doesn't match any saved location
                Label {
                    Text(String(format: "GPS: %.4f, %.4f", location.coordinate.latitude, location.coordinate.longitude))
                        .monospaced()
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

                let resolved = routineService.resolvedTemplate(template)
                HStack(spacing: 10) {
                    Label(
                        String(format: String(localized: "SmartTemplateSelectionView.HabitsCount", bundle: .module), resolved.activeHabitsCount),
                        systemImage: "list.bullet"
                    )
                    Label(resolved.formattedDuration, systemImage: "clock")

                    if !template.includes.isEmpty {
                        Image(systemName: "link")
                    }

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
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Theme.cardSurface)
                .shadow(color: .black.opacity(0.07), radius: 10, x: 0, y: 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            themeManager.currentAccentColor.opacity(0.45),
                            themeManager.currentAccentColor.opacity(0.12)
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
            // Paused Sessions Section
            if !routineService.pausedSessions.isEmpty {
                Section {
                    ForEach(routineService.pausedSessions) { snapshot in
                        PausedSessionRow(
                            snapshot: snapshot,
                            onResume: {
                                do {
                                    try routineService.resumeSession(withId: snapshot.id)
                                } catch {
                                    LoggingService.shared.error("Failed to resume session", category: .routine, metadata: ["error": error.localizedDescription])
                                }
                            },
                            onDiscard: {
                                routineService.discardPausedSession(withId: snapshot.id)
                            }
                        )
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                    }
                } header: {
                    Text(String(localized: "SmartTemplateSelectionView.PausedSection", bundle: .module))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                }
            }

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

            if let activeMode = modeService.activeMode {
                modeFooter(activeMode)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 4, trailing: 0))
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }
    
    /// Footer telling the user a mode is trimming the list — and how to get out of it.
    @ViewBuilder
    private func modeFooter(_ mode: RoutineMode) -> some View {
        let total = routineService.templates.count
        let isFiltering = modeService.isFiltering(routineService.templates)

        VStack(spacing: 6) {
            Text(isFiltering
                 ? "Showing \(sortedTemplates.count) of \(total) routines in \(mode.name)"
                 : "\(mode.name) has no routines yet — showing all \(total)")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                Button("Show All Routines") {
                    modeService.deactivate()
                }
                Button(isFiltering ? "Edit Mode" : "Choose Routines") {
                    showingModes = true
                }
            }
            .font(.caption.weight(.semibold))
            .buttonStyle(.plain)
            .foregroundStyle(themeManager.currentAccentColor)
        }
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
    }

    private var selectionTrigger: String {
        let context = routineService.routineSelector.currentContext
        let templateHash = routineService.templates.hashValue
        let location = String(describing: context.location)
        let timeSlot = context.timeSlot.rawValue
        let dayCategories = context.dayCategories.map(\.id).sorted().joined(separator: ",")
        let mode = modeService.activeMode.map { "\($0.id.uuidString)-\($0.templateIds.hashValue)" } ?? "none"
        return "\(templateHash)-\(location)-\(timeSlot)-\(dayCategories)-\(mode)"
    }

    private func selectSmartTemplate() async {
        let result = await routineService.getSmartTemplateAndSort()
        sortedTemplates = result.sorted
        selectedTemplate = result.best
        selectionReason = result.reason

        // Fallback to default logic if smart selection fails. Stay inside the
        // sorted (already mode-filtered) set so an active mode can't be bypassed.
        if selectedTemplate == nil {
            selectedTemplate = sortedTemplates.first(where: { $0.isDefault })
                            ?? sortedTemplates.first
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
            let locationMatch: Bool = {
                guard !rule.locationIds.isEmpty else { return false }
                switch context.extendedLocation {
                case .builtin(let locationType):
                    return rule.locationIds.contains(locationType.rawValue)
                case .custom(let id):
                    return rule.locationIds.contains(id.uuidString)
                }
            }()

            HStack(spacing: 4) {
                if !rule.timeSlots.isEmpty {
                    Image(systemName: timeMatch ? "clock.fill" : "clock")
                        .fontWeight(timeMatch ? .bold : .regular)
                        .foregroundStyle(timeMatch ? themeManager.currentAccentColor : .secondary)
                }
                if !rule.dayCategoryIds.isEmpty {
                    Image(systemName: "calendar")
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

                let resolved = routineService.resolvedTemplate(template)
                HStack(spacing: 6) {
                    if !template.includes.isEmpty {
                        Image(systemName: "link")
                            .font(.system(size: 9))
                    }
                    Text("\(String(format: String(localized: "SmartTemplateSelectionView.HabitsCount", bundle: .module), resolved.activeHabitsCount)) • \(resolved.formattedDuration)")
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
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    isSelected
                        ? AnyShapeStyle(themeManager.currentAccentColor.opacity(0.08))
                        : AnyShapeStyle(Theme.cardSurface)
                )
                .matchedGeometry(
                    id: .templateCard(templateId: template.id),
                    in: namespace,
                    isSource: true
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    isSelected ? themeManager.currentAccentColor.opacity(0.35) : Theme.hairline,
                    lineWidth: 1
                )
        )
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(template.name), \(routineService.resolvedTemplate(template).activeHabitsCount) habits, \(routineService.resolvedTemplate(template).formattedDuration)\(isSelected ? ", selected" : "")")
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
        .environment(RoutineModeService())
}