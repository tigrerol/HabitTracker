import SwiftUI

/// Enhanced view for customizing flexible day categories
struct DayTypeEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(RoutineService.self) private var routineService
    @Environment(DayCategoryManager.self) private var categoryManager

    @State private var categories: [DayCategory] = []
    @State private var weekdayAssignments: [Weekday: Set<String>] = [:]
    @State private var hasChanges = false
    @State private var showingCategoryCreator = false
    @State private var showingPresets = false
    @State private var categoryToEdit: DayCategory?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(String(localized: "DayTypeEditorView.Description", bundle: .module))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } header: {
                    Text(String(localized: "DayTypeEditorView.DayCategories.Title", bundle: .module))
                }

                // Category Management Section
                Section("Your Categories") {
                    ForEach(categories) { category in
                        CategoryRowView(
                            category: category,
                            onEdit: { categoryToEdit = category },
                            onDelete: categories.count > 2 ? { deleteCategory(category) } : nil
                        )
                    }

                    Button {
                        showingCategoryCreator = true
                    } label: {
                        Label("Add New Category", systemImage: "plus.circle")
                            .foregroundStyle(.blue)
                    }
                }

                // Day Assignment Section
                Section("Day Assignments") {
                    ForEach(Weekday.allCases, id: \.self) { weekday in
                        DayAssignmentRow(
                            weekday: weekday,
                            categories: categories,
                            selectedCategoryIds: weekdayAssignments[weekday] ?? Set(defaultCategoryIds(for: weekday)),
                            onSelectionChange: { categoryIds in
                                weekdayAssignments[weekday] = categoryIds
                                hasChanges = true
                            }
                        )
                    }
                }

                // Summary Section
                Section {
                    HStack {
                        Text(String(localized: "DayTypeEditorView.CurrentSetting.Title", bundle: .module))
                            .fontWeight(.medium)
                        Spacer()
                        Text(currentSummary)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                } header: {
                    Text(String(localized: "DayTypeEditorView.Summary.Title", bundle: .module))
                }

                // Tips Section
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(localized: "DayTypeEditorView.Examples.Title", bundle: .module))
                            .font(.subheadline)
                            .fontWeight(.medium)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(String(localized: "DayTypeEditorView.Examples.WorkRest", bundle: .module))
                            Text(String(localized: "DayTypeEditorView.Examples.GymStudy", bundle: .module))
                            Text(String(localized: "DayTypeEditorView.Examples.FirstSecond", bundle: .module))
                            Text(String(localized: "DayTypeEditorView.Examples.LazyProductive", bundle: .module))
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                } header: {
                    Text(String(localized: "DayTypeEditorView.Ideas.Title", bundle: .module))
                }

                // Presets Section
                Section {
                    Button("Choose Preset Schedule") {
                        showingPresets = true
                    }
                    .foregroundStyle(.blue)

                    Button("Reset to Standard") {
                        resetToStandard()
                    }
                    .foregroundStyle(.blue)
                }
            }
            .navigationTitle("Day Categories")

            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveSettings()
                        dismiss()
                    }
                    .disabled(!hasChanges)
                }
            }
        }
        .onAppear {
            loadSettings()
        }
        .sheet(isPresented: $showingCategoryCreator) {
            CategoryCreatorView { newCategory in
                categories.append(newCategory)
                hasChanges = true
            }
        }
        .sheet(item: $categoryToEdit) { category in
            CategoryCreatorView(editingCategory: category) { updatedCategory in
                if let index = categories.firstIndex(where: { $0.id == updatedCategory.id }) {
                    categories[index] = updatedCategory
                    hasChanges = true
                }
            }
        }
        .sheet(isPresented: $showingPresets) {
            DayCategoryPresetsView { preset in
                applyPreset(preset)
            }
        }
    }

    // MARK: - Helper Functions

    private func loadSettings() {
        let settings = categoryManager.getDayCategorySettings()
        categories = settings.getAllCategories()

        // Load current weekday assignments as sets
        for weekday in Weekday.allCases {
            let cats = settings.categories(for: weekday)
            weekdayAssignments[weekday] = Set(cats.map(\.id))
        }
    }

    private func saveSettings() {
        var newSettings = DayCategorySettings()

        // Add all categories
        for category in categories {
            newSettings.addCustomCategory(category)
        }

        // Set weekday assignments
        for (weekday, categoryIds) in weekdayAssignments {
            newSettings.setCategories(categoryIds, for: weekday)
        }

        categoryManager.updateDayCategorySettings(newSettings)
    }

    private func defaultCategoryIds(for weekday: Weekday) -> [String] {
        switch weekday {
        case .sunday, .saturday:
            return ["weekend"]
        case .monday, .tuesday, .wednesday, .thursday, .friday:
            return ["weekday"]
        }
    }

    private var currentSummary: String {
        // Group weekdays by their sorted category names
        let categoryGroups = Dictionary(grouping: Weekday.allCases) { weekday -> String in
            let ids = weekdayAssignments[weekday] ?? Set(defaultCategoryIds(for: weekday))
            let names = ids.compactMap { id in categories.first(where: { $0.id == id })?.name }
            return names.sorted().joined(separator: " + ")
        }

        if categoryGroups.count == 1, let categoryName = categoryGroups.keys.first {
            return "All days: \(categoryName)"
        }

        let summaryParts = categoryGroups.map { categoryName, weekdays in
            let dayNames = weekdays.map(\.shortName).joined(separator: ", ")
            return "\(categoryName): \(dayNames)"
        }.sorted()

        return summaryParts.joined(separator: "\n")
    }

    private func deleteCategory(_ category: DayCategory) {
        guard !category.isBuiltIn else { return }

        categories.removeAll { $0.id == category.id }

        // Remove this category from weekday assignments
        for weekday in Weekday.allCases {
            weekdayAssignments[weekday]?.remove(category.id)
            // If set becomes empty, assign defaults
            if weekdayAssignments[weekday]?.isEmpty ?? false {
                weekdayAssignments[weekday] = Set(defaultCategoryIds(for: weekday))
            }
        }

        hasChanges = true
    }

    private func resetToStandard() {
        categories = DayCategory.defaults
        weekdayAssignments = [:]
        hasChanges = true
    }

    private func applyPreset(_ preset: DayCategoryPreset) {
        categories = preset.categories
        weekdayAssignments = preset.assignments
        hasChanges = true
    }
}

// MARK: - Supporting Views

/// Row view for displaying and managing a single category
private struct CategoryRowView: View {
    let category: DayCategory
    let onEdit: () -> Void
    let onDelete: (() -> Void)?

    var body: some View {
        HStack {
            Label {
                Text(category.name)
                    .fontWeight(.medium)
            } icon: {
                Image(systemName: category.icon)
                    .foregroundStyle(category.color)
            }

            Spacer()

            if !category.isBuiltIn {
                Menu {
                    Button("Edit") {
                        onEdit()
                    }

                    if let onDelete = onDelete {
                        Button("Delete", role: .destructive) {
                            onDelete()
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

/// Row view for assigning multiple categories to a weekday using chips
private struct DayAssignmentRow: View {
    let weekday: Weekday
    let categories: [DayCategory]
    let selectedCategoryIds: Set<String>
    let onSelectionChange: (Set<String>) -> Void

    private var selectedCategories: [DayCategory] {
        categories.filter { selectedCategoryIds.contains($0.id) }
    }

    private var unselectedCategories: [DayCategory] {
        categories.filter { !selectedCategoryIds.contains($0.id) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                Text(weekday.displayName)
            } icon: {
                Image(systemName: weekday.icon)
                    .foregroundStyle(.blue)
            }

            // Category chips
            FlowLayout(spacing: 6) {
                ForEach(selectedCategories) { category in
                    CategoryChip(
                        category: category,
                        isRemovable: selectedCategoryIds.count > 1,
                        onRemove: {
                            var updated = selectedCategoryIds
                            updated.remove(category.id)
                            onSelectionChange(updated)
                        }
                    )
                }

                // Add button (only if there are unselected categories)
                if !unselectedCategories.isEmpty {
                    Menu {
                        ForEach(unselectedCategories) { category in
                            Button {
                                var updated = selectedCategoryIds
                                updated.insert(category.id)
                                onSelectionChange(updated)
                            } label: {
                                Label {
                                    Text(category.name)
                                } icon: {
                                    Image(systemName: category.icon)
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.blue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }
}

/// A chip representing an assigned category
private struct CategoryChip: View {
    let category: DayCategory
    let isRemovable: Bool
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: category.icon)
                .font(.caption2)
                .foregroundStyle(category.color)

            Text(category.name)
                .font(.caption)

            if isRemovable {
                Button {
                    onRemove()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(category.color.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
    }
}

/// Simple flow layout for wrapping chips
private struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            maxX = max(maxX, currentX)
        }

        return (CGSize(width: maxX, height: currentY + lineHeight), positions)
    }
}

/// View for creating or editing a category
private struct CategoryCreatorView: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: (DayCategory) -> Void
    let editingCategory: DayCategory?

    @State private var name: String
    @State private var selectedIcon: String
    @State private var selectedColor: Color
    @FocusState private var isNameFieldFocused: Bool

    private let availableIcons = [
        "briefcase", "house", "figure.walk", "dumbbell", "book", "gamecontroller",
        "music.note", "paintbrush", "camera", "leaf", "heart", "star",
        "moon", "sun.max", "cloud", "snowflake", "flame", "drop"
    ]

    init(editingCategory: DayCategory? = nil, onSave: @escaping (DayCategory) -> Void) {
        self.editingCategory = editingCategory
        self.onSave = onSave

        if let category = editingCategory {
            _name = State(initialValue: category.name)
            _selectedIcon = State(initialValue: category.icon)
            _selectedColor = State(initialValue: category.color)
        } else {
            _name = State(initialValue: "")
            _selectedIcon = State(initialValue: "star")
            _selectedColor = State(initialValue: .blue)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Category Details") {
                    TextField("Category Name", text: $name)
                        .focused($isNameFieldFocused)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(localized: "DayTypeEditorView.Icon.Title", bundle: .module))
                            .font(.subheadline)
                            .fontWeight(.medium)

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                            ForEach(availableIcons, id: \.self) { icon in
                                Button {
                                    selectedIcon = icon
                                } label: {
                                    Image(systemName: icon)
                                        .font(.title2)
                                        .foregroundStyle(selectedIcon == icon ? selectedColor : .secondary)
                                        .frame(width: 40, height: 40)
                                        .background(
                                            selectedIcon == icon ? selectedColor.opacity(0.1) : Color.clear,
                                            in: RoundedRectangle(cornerRadius: 8)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    ColorPicker("Color", selection: $selectedColor, supportsOpacity: false)
                }

                Section {
                    HStack {
                        Text(String(localized: "DayTypeEditorView.Preview.Title", bundle: .module))
                            .fontWeight(.medium)
                        Spacer()
                        Label {
                            Text(name.isEmpty ? "Your Category" : name)
                        } icon: {
                            Image(systemName: selectedIcon)
                                .foregroundStyle(selectedColor)
                        }
                    }
                }
            }
            .navigationTitle(editingCategory != nil ? "Edit Category" : "New Category")

            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveCategory()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .task {
            // Small delay to ensure TextField is fully rendered before focusing
            try? await Task.sleep(for: .milliseconds(100))
            isNameFieldFocused = true
        }
    }

    private func saveCategory() {
        let category = DayCategory(
            id: editingCategory?.id ?? UUID().uuidString,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            icon: selectedIcon,
            color: selectedColor,
            isBuiltIn: editingCategory?.isBuiltIn ?? false
        )
        onSave(category)
        dismiss()
    }
}

/// Preset data structure
private struct DayCategoryPreset {
    let name: String
    let description: String
    let categories: [DayCategory]
    let assignments: [Weekday: Set<String>]
}

/// View for selecting day category presets
private struct DayCategoryPresetsView: View {
    @Environment(\.dismiss) private var dismiss
    let onSelect: (DayCategoryPreset) -> Void

    private let presets: [DayCategoryPreset] = [
        createStandardPreset(),
        createWorkLifePreset(),
        createStudentPreset(),
        createShiftWorkerPreset(),
        createFreelancerPreset(),
        createFitnessPreset()
    ]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(String(localized: "DayTypeEditorView.PresetDescription", bundle: .module))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } header: {
                    Text(String(localized: "DayTypeEditorView.PresetSchedules.Title", bundle: .module))
                }

                ForEach(Array(presets.enumerated()), id: \.offset) { index, preset in
                    Button {
                        onSelect(preset)
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(preset.name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.primary)

                            Text(preset.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            // Show category preview
                            HStack(spacing: 12) {
                                ForEach(preset.categories) { category in
                                    Label {
                                        Text(category.name)
                                            .font(.caption2)
                                    } icon: {
                                        Image(systemName: category.icon)
                                            .font(.caption)
                                    }
                                    .foregroundStyle(category.color)
                                }
                            }
                            .font(.caption2)
                        }
                        .padding(.vertical, 2)
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("Preset Schedules")

            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Preset Creation Functions

    private static func createStandardPreset() -> DayCategoryPreset {
        DayCategoryPreset(
            name: "Standard Work Week",
            description: "Monday to Friday work, weekends off",
            categories: DayCategory.defaults,
            assignments: [
                .monday: Set(["weekday"]), .tuesday: Set(["weekday"]), .wednesday: Set(["weekday"]),
                .thursday: Set(["weekday"]), .friday: Set(["weekday"]),
                .saturday: Set(["weekend"]), .sunday: Set(["weekend"])
            ]
        )
    }

    private static func createWorkLifePreset() -> DayCategoryPreset {
        let workDays = DayCategory(name: "Work Days", icon: "briefcase", color: .blue, isBuiltIn: false)
        let meDays = DayCategory(name: "Me Days", icon: "heart", color: .pink, isBuiltIn: false)

        return DayCategoryPreset(
            name: "Work-Life Balance",
            description: "Focus days and personal time",
            categories: [workDays, meDays],
            assignments: [
                .monday: Set([workDays.id]), .tuesday: Set([workDays.id]), .wednesday: Set([workDays.id]),
                .thursday: Set([workDays.id]), .friday: Set([workDays.id]),
                .saturday: Set([meDays.id]), .sunday: Set([meDays.id])
            ]
        )
    }

    private static func createStudentPreset() -> DayCategoryPreset {
        let studyDays = DayCategory(name: "Study Days", icon: "book", color: .blue, isBuiltIn: false)
        let freeDays = DayCategory(name: "Free Days", icon: "gamecontroller", color: .green, isBuiltIn: false)

        return DayCategoryPreset(
            name: "Student Schedule",
            description: "Study weekdays, free weekends",
            categories: [studyDays, freeDays],
            assignments: [
                .monday: Set([studyDays.id]), .tuesday: Set([studyDays.id]), .wednesday: Set([studyDays.id]),
                .thursday: Set([studyDays.id]), .friday: Set([studyDays.id]),
                .saturday: Set([freeDays.id]), .sunday: Set([freeDays.id])
            ]
        )
    }

    private static func createShiftWorkerPreset() -> DayCategoryPreset {
        let workDays = DayCategory(name: "Shift Days", icon: "briefcase", color: .orange, isBuiltIn: false)
        let restDays = DayCategory(name: "Rest Days", icon: "house", color: .green, isBuiltIn: false)

        return DayCategoryPreset(
            name: "Shift Worker (4 on, 3 off)",
            description: "Four work days, three rest days",
            categories: [workDays, restDays],
            assignments: [
                .monday: Set([workDays.id]), .tuesday: Set([workDays.id]), .wednesday: Set([workDays.id]),
                .thursday: Set([workDays.id]),
                .friday: Set([restDays.id]), .saturday: Set([restDays.id]), .sunday: Set([restDays.id])
            ]
        )
    }

    private static func createFreelancerPreset() -> DayCategoryPreset {
        let clientDays = DayCategory(name: "Client Work", icon: "briefcase", color: .blue, isBuiltIn: false)
        let projectDays = DayCategory(name: "Personal Projects", icon: "paintbrush", color: .purple, isBuiltIn: false)
        let restDays = DayCategory(name: "Rest Days", icon: "leaf", color: .green, isBuiltIn: false)

        return DayCategoryPreset(
            name: "Freelancer Schedule",
            description: "Client work, personal projects, rest",
            categories: [clientDays, projectDays, restDays],
            assignments: [
                .monday: Set([clientDays.id]), .tuesday: Set([clientDays.id]), .wednesday: Set([clientDays.id]),
                .thursday: Set([projectDays.id]), .friday: Set([projectDays.id]),
                .saturday: Set([restDays.id]), .sunday: Set([restDays.id])
            ]
        )
    }

    private static func createFitnessPreset() -> DayCategoryPreset {
        let gymDays = DayCategory(name: "Gym Days", icon: "dumbbell", color: .red, isBuiltIn: false)
        let activeDays = DayCategory(name: "Active Days", icon: "figure.walk", color: .orange, isBuiltIn: false)
        let restDays = DayCategory(name: "Rest Days", icon: "leaf", color: .green, isBuiltIn: false)

        return DayCategoryPreset(
            name: "Fitness Focus",
            description: "Gym, active recovery, rest days",
            categories: [gymDays, activeDays, restDays],
            assignments: [
                .monday: Set([gymDays.id]), .tuesday: Set([activeDays.id]), .wednesday: Set([gymDays.id]),
                .thursday: Set([activeDays.id]), .friday: Set([gymDays.id]),
                .saturday: Set([activeDays.id]), .sunday: Set([restDays.id])
            ]
        )
    }
}

#Preview {
    DayTypeEditorView()
        .environment(RoutineService())
        .environment(DayCategoryManager.shared)
}
