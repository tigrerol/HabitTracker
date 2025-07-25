import SwiftUI

/// Sheet for editing habit details
public struct HabitEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(RoutineService.self) private var routineService
    
    @State private var habit: Habit
    @State private var habitName: String
    @State private var habitColor: String
    @State private var isOptional: Bool
    @State private var notes: String
    
    // Type-specific state
    @State private var timerDuration: TimeInterval = 300
    @State private var restTimerTarget: TimeInterval? = nil
    @State private var appBundleId: String = ""
    @State private var appName: String = ""
    @State private var websiteURL: String = ""
    @State private var websiteTitle: String = ""
    @State private var counterItems: [String] = []
    @State private var measurementUnit: String = ""
    @State private var measurementTarget: Double? = nil
    @State private var subtasks: [Subtask] = []
    @State private var sequenceSteps: [SequenceStep] = []
    @State private var launchMethod: LaunchMethod = .shortcut
    
    // Launch method enum
    private enum LaunchMethod {
        case shortcut
        case urlScheme
    }
    
    let onSave: (Habit) -> Void
    
    public init(habit: Habit, onSave: @escaping (Habit) -> Void) {
        print("🔍 HabitEditorView: init called with habit: \(habit.name), type: \(habit.type)")
        
        self._habit = State(initialValue: habit)
        self._habitName = State(initialValue: habit.name)
        self._habitColor = State(initialValue: habit.color)
        self._isOptional = State(initialValue: habit.isOptional)
        self._notes = State(initialValue: habit.notes ?? "")
        self.onSave = onSave
        
        // Initialize type-specific state
        switch habit.type {
        case .timer(let duration):
            self._timerDuration = State(initialValue: duration)
        case .restTimer(let target):
            self._restTimerTarget = State(initialValue: target)
        case .appLaunch(let bundleId, let name):
            self._appBundleId = State(initialValue: bundleId)
            self._appName = State(initialValue: name)
            // Determine launch method based on bundleId format
            self._launchMethod = State(initialValue: bundleId.contains("://") ? .urlScheme : .shortcut)
        case .website(let url, let title):
            self._websiteURL = State(initialValue: url.absoluteString)
            self._websiteTitle = State(initialValue: title)
        case .counter(let items):
            self._counterItems = State(initialValue: items)
        case .measurement(let unit, let target):
            self._measurementUnit = State(initialValue: unit)
            self._measurementTarget = State(initialValue: target)
        case .checkboxWithSubtasks(let tasks):
            print("🔍 HabitEditorView: init - checkboxWithSubtasks with \(tasks.count) tasks")
            for (index, task) in tasks.enumerated() {
                print("🔍 HabitEditorView: init - subtask \(index): '\(task.name)' (id: \(task.id))")
            }
            self._subtasks = State(initialValue: tasks)
        case .checkbox:
            print("🔍 HabitEditorView: init - checkbox type, initializing empty subtasks")
            self._subtasks = State(initialValue: [])
        case .guidedSequence(let steps):
            self._sequenceSteps = State(initialValue: steps)
        case .conditional:
            // Conditional habits will redirect to ConditionalHabitEditorView
            break
        }
    }
    
    public var body: some View {
        let _ = print("🔍 HabitEditorView: body called with habitName: \(habitName)")
        
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                // Basic info
                VStack(alignment: .leading, spacing: 16) {
                    Text(String(localized: "HabitEditorView.BasicInformation.Title", bundle: .module))
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    TextField(String(localized: "HabitEditorView.BasicInformation.HabitName.Placeholder", bundle: .module), text: $habitName)
                        .textFieldStyle(.roundedBorder)
                    
                    Toggle(String(localized: "HabitEditorView.BasicInformation.OptionalHabit.Label", bundle: .module), isOn: $isOptional)
                    
                    // Color picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(localized: "HabitEditorView.BasicInformation.Color.Label", bundle: .module))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        HStack(spacing: 12) {
                            ForEach(["#34C759", "#007AFF", "#FF9500", "#FF3B30", "#AF52DE", "#5AC8FA", "#FFD60A", "#FF2D55"], id: \.self) { color in
                                Circle()
                                    .fill(Color(hex: color) ?? .blue)
                                    .frame(width: 32, height: 32)
                                    .overlay {
                                        if habitColor == color {
                                            Image(systemName: "checkmark")
                                                .font(.caption)
                                                .fontWeight(.bold)
                                                .foregroundStyle(.white)
                                        }
                                    }
                                    .onTapGesture {
                                        habitColor = color
                                    }
                            }
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 10))
                
                // Type-specific settings
                typeSpecificSection
                
                // Notes
                VStack(alignment: .leading, spacing: 8) {
                    Text(String(localized: "HabitEditorView.BasicInformation.Notes.Title", bundle: .module))
                        .font(.headline)
                    
                    TextField(String(localized: "HabitEditorView.BasicInformation.Notes.Placeholder", bundle: .module), text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                        .textFieldStyle(.roundedBorder)
                }
                .padding()
                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 10))
                }
                .padding()
            }
            .navigationTitle(String(localized: "HabitEditorView.NavigationTitle", bundle: .module))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "HabitEditorView.Cancel.Button", bundle: .module)) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "HabitEditorView.Save.Button", bundle: .module)) {
                        saveHabit()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    // MARK: - Type-Specific Sections
    
    @ViewBuilder
    private var typeSpecificSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: habit.type.iconName)
                    .foregroundStyle(.blue)
                Text(habitTypeTitle)
                    .font(.headline)
            }
            
            switch habit.type {
            case .checkbox:
                let _ = print("typeSpecificSection: showing checkbox")
                subtasksEditor
                
            case .checkboxWithSubtasks:
                let _ = print("typeSpecificSection: showing checkboxWithSubtasks")
                subtasksEditor
                
            case .timer:
                let _ = print("typeSpecificSection: showing timer")
                timerSettings
                
            case .restTimer:
                restTimerSettings
                
            case .appLaunch:
                appLaunchSettings
                
            case .website:
                websiteSettings
                
            case .counter:
                counterItemsEditor
                
            case .measurement:
                measurementSettings
                
            case .guidedSequence:
                sequenceEditor
                
            case .conditional:
                VStack(spacing: 12) {
                    Text(String(localized: "HabitEditorView.Question.Instructions", bundle: .module))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .italic()
                    
                    NavigationLink(destination: ConditionalHabitEditorView(
                        existingHabit: habit,
                        habitLibrary: habitLibrary,
                        existingConditionalDepth: 0,
                        onSave: onSave
                    )) {
                        Label(String(localized: "HabitEditorView.Question.OpenEditor.Label", bundle: .module), systemImage: "questionmark.circle")
                            .font(.subheadline)
                            .foregroundStyle(.blue)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 10))
    }
    
    private var habitTypeTitle: String {
        switch habit.type {
        case .checkbox:
            return String(localized: "HabitType.Checkbox.Title", bundle: .module)
        case .checkboxWithSubtasks:
            return String(localized: "HabitType.CheckboxWithSubtasks.Title", bundle: .module)
        case .timer:
            return String(localized: "HabitType.Timer.Title", bundle: .module)
        case .restTimer:
            return String(localized: "HabitType.RestTimer.Title", bundle: .module)
        case .appLaunch:
            return String(localized: "HabitType.AppLaunch.Title", bundle: .module)
        case .website:
            return String(localized: "HabitType.Website.Title", bundle: .module)
        case .counter:
            return String(localized: "HabitType.Counter.Title", bundle: .module)
        case .measurement:
            return String(localized: "HabitType.Measurement.Title", bundle: .module)
        case .guidedSequence:
            return String(localized: "HabitType.Sequence.Title", bundle: .module)
        case .conditional:
            return String(localized: "HabitType.Question.Title", bundle: .module)
        }
    }
    
    /// Get all available habits from all templates to use as a library
    private var habitLibrary: [Habit] {
        routineService.templates.flatMap { $0.habits }.filter { $0.isActive }
    }
    
    // Timer settings
    private var timerSettings: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(String(localized: "HabitEditorView.Timer.Duration.Label", bundle: .module))
                Spacer()
                Text(timerDuration.formattedDuration)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "HabitEditorView.Timer.Minutes.Label", bundle: .module))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    TextField("0", value: Binding(
                        get: { Int(timerDuration) / 60 },
                        set: { newMinutes in
                            let seconds = Int(timerDuration) % 60
                            timerDuration = TimeInterval(max(0, newMinutes) * 60 + seconds)
                        }
                    ), format: .number)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "HabitEditorView.Timer.Seconds.Label", bundle: .module))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    TextField("0", value: Binding(
                        get: { Int(timerDuration) % 60 },
                        set: { newSeconds in
                            let minutes = Int(timerDuration) / 60
                            timerDuration = TimeInterval(minutes * 60 + max(0, min(59, newSeconds)))
                        }
                    ), format: .number)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                }
                
                Spacer()
            }
            
            // Quick preset buttons
            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "HabitEditorView.Timer.QuickPresets.Title", bundle: .module))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach([
                            (30, "30s"),
                            (60, "1m"),
                            (120, "2m"),
                            (300, "5m"),
                            (600, "10m"),
                            (900, "15m"),
                            (1200, "20m"),
                            (1800, "30m")
                        ], id: \.0) { duration, label in
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    timerDuration = TimeInterval(duration)
                                }
                            } label: {
                                Text(label)
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        timerDuration == TimeInterval(duration) ? 
                                        Color.blue.opacity(0.2) : Color(.systemGray5),
                                        in: Capsule()
                                    )
                                    .foregroundStyle(
                                        timerDuration == TimeInterval(duration) ? .blue : .primary
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 1)
                }
            }
        }
    }
    
    // Rest timer settings
    private var restTimerSettings: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(String(localized: "HabitEditorView.RestTimer.SetTarget.Toggle", bundle: .module), isOn: Binding(
                get: { restTimerTarget != nil },
                set: { enabled in
                    restTimerTarget = enabled ? 120 : nil
                }
            ))
            
            if let target = restTimerTarget {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(String(localized: "HabitEditorView.RestTimer.Target.Label", bundle: .module))
                        Spacer()
                        Text(target.formattedDuration)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(String(localized: "HabitEditorView.Timer.Minutes.Label", bundle: .module))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            TextField("0", value: Binding(
                                get: { Int(target) / 60 },
                                set: { newMinutes in
                                    let seconds = Int(target) % 60
                                    restTimerTarget = TimeInterval(max(0, newMinutes) * 60 + seconds)
                                }
                            ), format: .number)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(String(localized: "HabitEditorView.Timer.Seconds.Label", bundle: .module))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            TextField("0", value: Binding(
                                get: { Int(target) % 60 },
                                set: { newSeconds in
                                    let minutes = Int(target) / 60
                                    restTimerTarget = TimeInterval(minutes * 60 + max(0, min(59, newSeconds)))
                                }
                            ), format: .number)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                        }
                        
                        Spacer()
                    }
                    
                    // Quick preset buttons for rest timer
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(localized: "HabitEditorView.Timer.QuickPresets.Title", bundle: .module))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach([
                                    (30, "30s"),
                                    (60, "1m"),
                                    (90, "90s"),
                                    (120, "2m"),
                                    (180, "3m"),
                                    (300, "5m")
                                ], id: \.0) { duration, label in
                                    Button {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            restTimerTarget = TimeInterval(duration)
                                        }
                                    } label: {
                                        Text(label)
                                            .font(.caption)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(
                                                restTimerTarget == TimeInterval(duration) ? 
                                                Color.blue.opacity(0.2) : Color(.systemGray5),
                                                in: Capsule()
                                            )
                                            .foregroundStyle(
                                                restTimerTarget == TimeInterval(duration) ? .blue : .primary
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 1)
                        }
                    }
                }
            }
        }
    }
    
    // App launch settings
    private var appLaunchSettings: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField(String(localized: "HabitEditorView.AppLaunch.DisplayName.Placeholder", bundle: .module), text: $appName)
                .textFieldStyle(.roundedBorder)
            
            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "HabitEditorView.AppLaunch.LaunchMethod.Label", bundle: .module))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Picker(String(localized: "HabitEditorView.AppLaunch.LaunchMethod.Picker.Label", bundle: .module), selection: $launchMethod) {
                    Text(String(localized: "HabitEditorView.AppLaunch.Shortcut.Label", bundle: .module)).tag(LaunchMethod.shortcut)
                    Text(String(localized: "HabitEditorView.AppLaunch.URLScheme.Label", bundle: .module)).tag(LaunchMethod.urlScheme)
                }
                .pickerStyle(.segmented)
                
                if launchMethod == .shortcut {
                    VStack(alignment: .leading, spacing: 4) {
                        TextField(String(localized: "HabitEditorView.AppLaunch.ShortcutName.Placeholder", bundle: .module), text: $appBundleId)
                            .textFieldStyle(.roundedBorder)
                        
                        Text(String(localized: "HabitEditorView.AppLaunch.ShortcutName.Instructions", bundle: .module))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        TextField(String(localized: "HabitEditorView.AppLaunch.URLScheme.Placeholder", bundle: .module), text: $appBundleId)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .textFieldStyle(.roundedBorder)
                        
                        Text(String(localized: "HabitEditorView.AppLaunch.URLScheme.Examples", bundle: .module))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
    
    // Website settings
    private var websiteSettings: some View {
        Group {
            TextField(String(localized: "HabitEditorView.Website.Title.Placeholder", bundle: .module), text: $websiteTitle)
            TextField(String(localized: "HabitEditorView.Website.URL.Placeholder", bundle: .module), text: $websiteURL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
        }
    }
    
    // Measurement settings
    private var measurementSettings: some View {
        Group {
            TextField(String(localized: "HabitEditorView.Measurement.Unit.Placeholder", bundle: .module), text: $measurementUnit)
            
            HStack {
                Toggle(String(localized: "HabitEditorView.Measurement.SetTarget.Toggle", bundle: .module), isOn: Binding(
                    get: { measurementTarget != nil },
                    set: { enabled in
                        measurementTarget = enabled ? 0 : nil
                    }
                ))
                
                if measurementTarget != nil {
                    TextField(String(localized: "HabitEditorView.Measurement.Target.Placeholder", bundle: .module), value: Binding(
                        get: { measurementTarget ?? 0 },
                        set: { measurementTarget = $0 }
                    ), format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                }
            }
        }
    }
    
    // Subtasks editor
    private var subtasksEditor: some View {
        let _ = print("🔍 subtasksEditor: Rendering with \(subtasks.count) subtasks")
        return VStack(alignment: .leading, spacing: 8) {
            if subtasks.isEmpty {
                Text(String(localized: "HabitEditorView.Subtasks.NoSubtasks.Message", bundle: .module))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .italic()
            } else {
                ForEach(subtasks) { subtask in
                    HStack {
                        TextField(String(localized: "HabitEditorView.Subtasks.Subtask.Placeholder", bundle: .module), text: Binding(
                            get: { subtask.name },
                            set: { newName in
                                if let index = subtasks.firstIndex(where: { $0.id == subtask.id }) {
                                    print("🔍 subtasksEditor: Updating subtask at index \(index) to '\(newName)'")
                                    subtasks[index].name = newName
                                }
                            }
                        ))
                        .textFieldStyle(.roundedBorder)
                        
                        Button {
                            withAnimation {
                                print("🔍 subtasksEditor: Removing subtask '\(subtask.name)'")
                                subtasks.removeAll { $0.id == subtask.id }
                            }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            
            Button {
                withAnimation {
                    let newSubtask = Subtask(name: String(localized: "HabitEditorView.Subtasks.NewSubtask.Default", bundle: .module))
                    print("🔍 subtasksEditor: Adding new subtask with id \(newSubtask.id)")
                    subtasks.append(newSubtask)
                    print("🔍 subtasksEditor: subtasks.count is now \(subtasks.count)")
                }
            } label: {
                Label(String(localized: "HabitEditorView.Subtasks.AddSubtask.Label", bundle: .module), systemImage: "plus.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.blue)
            }
        }
    }
    
    
    // Counter items editor
    private var counterItemsEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "HabitEditorView.Counter.ItemsToTrack.Title", bundle: .module))
                .font(.caption)
                .foregroundStyle(.secondary)
            
            TextField(String(localized: "HabitEditorView.Counter.Items.Placeholder", bundle: .module), text: Binding(
                get: { counterItems.joined(separator: ", ") },
                set: { newValue in
                    counterItems = newValue.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                }
            ), axis: .vertical)
            .lineLimit(3...6)
            .textFieldStyle(.roundedBorder)
            
            Text(String(localized: "HabitEditorView.Counter.Instructions", bundle: .module))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
    
    // Sequence editor
    @ViewBuilder
    private var sequenceEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(sequenceSteps) { step in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        TextField(String(localized: "HabitEditorView.Sequence.StepName.Placeholder", bundle: .module), text: Binding(
                            get: { step.name },
                            set: { newName in
                                if let index = sequenceSteps.firstIndex(where: { $0.id == step.id }) {
                                    sequenceSteps[index].name = newName
                                }
                            }
                        ))
                        
                        HStack(spacing: 4) {
                            TextField(String(localized: "HabitEditorView.Sequence.Duration.Placeholder", bundle: .module), value: Binding(
                                get: { Int(step.duration) },
                                set: { newValue in
                                    if let index = sequenceSteps.firstIndex(where: { $0.id == step.id }) {
                                        sequenceSteps[index].duration = TimeInterval(max(1, newValue))
                                    }
                                }
                            ), format: .number)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 60)
                            
                            Text(String(localized: "HabitEditorView.Sequence.Seconds.Label", bundle: .module))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Button {
                            withAnimation {
                                sequenceSteps.removeAll { $0.id == step.id }
                            }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.red)
                        }
                    }
                    
                    TextField(String(localized: "HabitEditorView.Sequence.Instructions.Placeholder", bundle: .module), text: Binding(
                        get: { step.instructions ?? "" },
                        set: { newInstructions in
                            if let index = sequenceSteps.firstIndex(where: { $0.id == step.id }) {
                                sequenceSteps[index].instructions = newInstructions.isEmpty ? nil : newInstructions
                            }
                        }
                    ), axis: .vertical)
                    .font(.caption)
                    .lineLimit(2...3)
                }
                .padding(.vertical, 4)
            }
            
            Button {
                withAnimation {
                    sequenceSteps.append(SequenceStep(name: String(localized: "HabitEditorView.Sequence.NewStep.Default", bundle: .module), duration: 30))
                }
            } label: {
                Label(String(localized: "HabitEditorView.Sequence.AddStep.Label", bundle: .module), systemImage: "plus.circle.fill")
                    .font(.subheadline)
            }
        }
    }
    
    // MARK: - Save
    
    private func saveHabit() {
        print("🔍 saveHabit: Starting save process")
        print("🔍 saveHabit: habitName = '\(habitName)'")
        print("🔍 saveHabit: habit.type = \(habit.type)")
        print("🔍 saveHabit: subtasks.count = \(subtasks.count)")
        
        var updatedHabit = habit
        updatedHabit.name = habitName
        updatedHabit.color = habitColor
        updatedHabit.isOptional = isOptional
        updatedHabit.notes = notes.isEmpty ? nil : notes
        
        // Update type with new values
        switch habit.type {
        case .checkbox:
            print("🔍 saveHabit: Processing checkbox type")
            // Convert to checkboxWithSubtasks if subtasks were added
            if !subtasks.isEmpty {
                print("🔍 saveHabit: Converting to checkboxWithSubtasks with \(subtasks.count) subtasks")
                for (index, subtask) in subtasks.enumerated() {
                    print("🔍 saveHabit: Subtask \(index): '\(subtask.name)' (id: \(subtask.id))")
                }
                updatedHabit.type = .checkboxWithSubtasks(subtasks: subtasks)
            } else {
                print("🔍 saveHabit: Keeping as checkbox (no subtasks)")
                updatedHabit.type = .checkbox
            }
        case .timer:
            updatedHabit.type = .timer(defaultDuration: timerDuration)
        case .restTimer:
            updatedHabit.type = .restTimer(targetDuration: restTimerTarget)
        case .appLaunch:
            updatedHabit.type = .appLaunch(bundleId: appBundleId, appName: appName)
        case .website:
            if let url = URL(string: websiteURL) {
                updatedHabit.type = .website(url: url, title: websiteTitle)
            }
        case .counter:
            updatedHabit.type = .counter(items: counterItems.filter { !$0.isEmpty })
        case .measurement:
            updatedHabit.type = .measurement(unit: measurementUnit, targetValue: measurementTarget)
        case .checkboxWithSubtasks:
            print("🔍 saveHabit: Processing checkboxWithSubtasks type")
            print("🔍 saveHabit: Saving with \(subtasks.count) subtasks")
            for (index, subtask) in subtasks.enumerated() {
                print("🔍 saveHabit: Subtask \(index): '\(subtask.name)' (id: \(subtask.id))")
            }
            updatedHabit.type = .checkboxWithSubtasks(subtasks: subtasks)
        case .guidedSequence:
            updatedHabit.type = .guidedSequence(steps: sequenceSteps)
        case .conditional:
            // Don't modify conditional habits in this editor
            break
        }
        
        print("🔍 saveHabit: Final updatedHabit.type = \(updatedHabit.type)")
        onSave(updatedHabit)
        dismiss()
    }
}

#Preview {
    HabitEditorView(
        habit: Habit(
            name: "Morning Stretch",
            type: .timer(defaultDuration: 600),
            color: "#007AFF"
        )
    ) { _ in }
}