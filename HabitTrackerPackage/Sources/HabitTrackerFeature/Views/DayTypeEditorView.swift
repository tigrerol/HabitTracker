import SwiftUI

/// Enhanced view for customizing flexible day categories
struct DayTypeEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(RoutineService.self) private var routineService
    @Environment(DayCategoryManager.self) private var categoryManager
    
    @State private var categories: [DayCategory] = []
    @State private var weekdayAssignments: [Weekday: String] = [:]
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
                            selectedCategoryId: weekdayAssignments[weekday] ?? defaultCategoryId(for: weekday),
                            onSelectionChange: { categoryId in
                                weekdayAssignments[weekday] = categoryId
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
        
        // Load current weekday assignments
        for weekday in Weekday.allCases {
            let category = settings.category(for: weekday)
            weekdayAssignments[weekday] = category.id
        }
    }
    
    private func saveSettings() {
        var newSettings = DayCategorySettings()
        
        // Add all categories
        for category in categories {
            newSettings.addCustomCategory(category)
        }
        
        // Set weekday assignments
        for (weekday, categoryId) in weekdayAssignments {
            newSettings.setCategory(categoryId, for: weekday)
        }
        
        categoryManager.updateDayCategorySettings(newSettings)
    }
    
    private func defaultCategoryId(for weekday: Weekday) -> String {
        switch weekday {
        case .sunday, .saturday:
            return "weekend"
        case .monday, .tuesday, .wednesday, .thursday, .friday:
            return "weekday"
        }
    }
    
    private var currentSummary: String {
        let categoryGroups = Dictionary(grouping: Weekday.allCases) { weekday in
            let categoryId = weekdayAssignments[weekday] ?? defaultCategoryId(for: weekday)
            return categories.first(where: { $0.id == categoryId })?.name ?? "Unknown"
        }
        
        if categoryGroups.count == 1, let categoryName = categoryGroups.keys.first {
            return "All days: \(categoryName)"
        }
        
        let summaryParts = categoryGroups.map { categoryName, weekdays in
            let dayNames = weekdays.map(\.shortName).joined(separator: ", ")
            return "\(categoryName): \(dayNames)"
        }
        
        return summaryParts.joined(separator: "\n")
    }
    
    private func deleteCategory(_ category: DayCategory) {
        guard !category.isBuiltIn else { return }
        
        categories.removeAll { $0.id == category.id }
        
        // Reassign weekdays using this category to default
        for weekday in Weekday.allCases {
            if weekdayAssignments[weekday] == category.id {
                weekdayAssignments[weekday] = defaultCategoryId(for: weekday)
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

/// Row view for assigning a category to a weekday
private struct DayAssignmentRow: View {
    let weekday: Weekday
    let categories: [DayCategory]
    let selectedCategoryId: String
    let onSelectionChange: (String) -> Void
    
    var body: some View {
        HStack {
            Label {
                Text(weekday.displayName)
            } icon: {
                Image(systemName: weekday.icon)
                    .foregroundStyle(.blue)
            }
            
            Spacer()
            
            Menu {
                ForEach(categories) { category in
                    Button {
                        onSelectionChange(category.id)
                    } label: {
                        Label {
                            Text(category.name)
                        } icon: {
                            Image(systemName: category.icon)
                        }
                    }
                }
            } label: {
                HStack {
                    if let selectedCategory = categories.first(where: { $0.id == selectedCategoryId }) {
                        Image(systemName: selectedCategory.icon)
                            .foregroundStyle(selectedCategory.color)
                        Text(selectedCategory.name)
                            .foregroundStyle(.primary)
                    } else {
                        Text(String(localized: "DayTypeEditorView.SelectCategory.Title", bundle: .module))
                            .foregroundStyle(.secondary)
                    }
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
            }
        }
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
    let assignments: [Weekday: String]
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
                .monday: "weekday", .tuesday: "weekday", .wednesday: "weekday",
                .thursday: "weekday", .friday: "weekday",
                .saturday: "weekend", .sunday: "weekend"
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
                .monday: workDays.id, .tuesday: workDays.id, .wednesday: workDays.id,
                .thursday: workDays.id, .friday: workDays.id,
                .saturday: meDays.id, .sunday: meDays.id
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
                .monday: studyDays.id, .tuesday: studyDays.id, .wednesday: studyDays.id,
                .thursday: studyDays.id, .friday: studyDays.id,
                .saturday: freeDays.id, .sunday: freeDays.id
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
                .monday: workDays.id, .tuesday: workDays.id, .wednesday: workDays.id,
                .thursday: workDays.id,
                .friday: restDays.id, .saturday: restDays.id, .sunday: restDays.id
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
                .monday: clientDays.id, .tuesday: clientDays.id, .wednesday: clientDays.id,
                .thursday: projectDays.id, .friday: projectDays.id,
                .saturday: restDays.id, .sunday: restDays.id
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
                .monday: gymDays.id, .tuesday: activeDays.id, .wednesday: gymDays.id,
                .thursday: activeDays.id, .friday: gymDays.id,
                .saturday: activeDays.id, .sunday: restDays.id
            ]
        )
    }
}

/// Legacy view for selecting day type presets
private struct DayTypePresetsView: View {
    @Environment(\.dismiss) private var dismiss
    let onSelect: (DayCategorySettings) -> Void
    
    private let presets: [(name: String, description: String, settings: DayCategorySettings)] = [
        ("Standard Work Week", "Monday to Friday work, weekends off", createStandardWeek()),
        ("Sunday Work Week", "Sunday to Thursday work, Friday-Saturday off", createSundayWorkWeek()),
        ("4-Day Work Week", "Monday to Thursday work, Friday-Sunday off", createFourDayWeek()),
        ("Shift Worker (3 on, 4 off)", "Work Mon/Tue/Wed, off Thu-Sun", createShiftWorkerA()),
        ("Shift Worker (4 on, 3 off)", "Work Thu/Fri/Sat/Sun, off Mon-Wed", createShiftWorkerB()),
        ("Every Other Day", "Alternating work and rest days", createAlternatingSchedule()),
        ("All Weekdays", "Every day is a work day", createAllWeekdays()),
        ("All Weekends", "Every day is a rest day", createAllWeekends())
    ]
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(String(localized: "DayTypeEditorView.WorkPatternDescription", bundle: .module))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } header: {
                    Text(String(localized: "DayTypeEditorView.PresetSchedules.Title", bundle: .module))
                }
                
                ForEach(Array(presets.enumerated()), id: \.offset) { index, preset in
                    Button {
                        onSelect(preset.settings)
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(preset.name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.primary)
                            
                            Text(preset.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Text(preset.settings.summary)
                                .font(.caption)
                                .foregroundStyle(.blue)
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
    
    private static func createStandardWeek() -> DayCategorySettings {
        var settings = DayCategorySettings()
        settings.setCategory("weekday", for: .monday)
        settings.setCategory("weekday", for: .tuesday)
        settings.setCategory("weekday", for: .wednesday)
        settings.setCategory("weekday", for: .thursday)
        settings.setCategory("weekday", for: .friday)
        settings.setCategory("weekend", for: .saturday)
        settings.setCategory("weekend", for: .sunday)
        return settings
    }
    
    private static func createSundayWorkWeek() -> DayCategorySettings {
        var settings = DayCategorySettings()
        settings.setCategory("weekday", for: .sunday)
        settings.setCategory("weekday", for: .monday)
        settings.setCategory("weekday", for: .tuesday)
        settings.setCategory("weekday", for: .wednesday)
        settings.setCategory("weekday", for: .thursday)
        settings.setCategory("weekend", for: .friday)
        settings.setCategory("weekend", for: .saturday)
        return settings
    }
    
    private static func createFourDayWeek() -> DayCategorySettings {
        var settings = DayCategorySettings()
        settings.setCategory("weekday", for: .monday)
        settings.setCategory("weekday", for: .tuesday)
        settings.setCategory("weekday", for: .wednesday)
        settings.setCategory("weekday", for: .thursday)
        settings.setCategory("weekend", for: .friday)
        settings.setCategory("weekend", for: .saturday)
        settings.setCategory("weekend", for: .sunday)
        return settings
    }
    
    private static func createShiftWorkerA() -> DayCategorySettings {
        var settings = DayCategorySettings()
        settings.setCategory("weekday", for: .monday)
        settings.setCategory("weekday", for: .tuesday)
        settings.setCategory("weekday", for: .wednesday)
        settings.setCategory("weekend", for: .thursday)
        settings.setCategory("weekend", for: .friday)
        settings.setCategory("weekend", for: .saturday)
        settings.setCategory("weekend", for: .sunday)
        return settings
    }
    
    private static func createShiftWorkerB() -> DayCategorySettings {
        var settings = DayCategorySettings()
        settings.setCategory("weekend", for: .monday)
        settings.setCategory("weekend", for: .tuesday)
        settings.setCategory("weekend", for: .wednesday)
        settings.setCategory("weekday", for: .thursday)
        settings.setCategory("weekday", for: .friday)
        settings.setCategory("weekday", for: .saturday)
        settings.setCategory("weekday", for: .sunday)
        return settings
    }
    
    private static func createAlternatingSchedule() -> DayCategorySettings {
        var settings = DayCategorySettings()
        settings.setCategory("weekday", for: .monday)
        settings.setCategory("weekend", for: .tuesday)
        settings.setCategory("weekday", for: .wednesday)
        settings.setCategory("weekend", for: .thursday)
        settings.setCategory("weekday", for: .friday)
        settings.setCategory("weekend", for: .saturday)
        settings.setCategory("weekday", for: .sunday)
        return settings
    }
    
    private static func createAllWeekdays() -> DayCategorySettings {
        var settings = DayCategorySettings()
        for weekday in Weekday.allCases {
            settings.setCategory("weekday", for: weekday)
        }
        return settings
    }
    
    private static func createAllWeekends() -> DayCategorySettings {
        var settings = DayCategorySettings()
        for weekday in Weekday.allCases {
            settings.setCategory("weekend", for: weekday)
        }
        return settings
    }
}

#Preview {
    DayTypeEditorView()
        .environment(RoutineService())
        .environment(DayCategoryManager.shared)
}