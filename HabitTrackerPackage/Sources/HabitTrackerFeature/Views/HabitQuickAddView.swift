import SwiftUI

/// Quick add bar with smart type detection and live preview for creating habits
struct HabitQuickAddView: View {
    @State private var inputText = ""
    @State private var showingTypePicker = false
    @State private var detectedType: HabitType?
    @State private var previewHabit: Habit?
    @State private var showingPreview = false
    @FocusState private var isInputFocused: Bool
    
    let onAdd: (Habit) -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            // Input field
            HStack {
                Image(systemName: detectedTypeIcon)
                    .font(.body)
                    .foregroundStyle(detectedTypeColor)
                    .frame(width: 24)
                
                TextField(String(localized: "HabitQuickAddView.AddHabit.Placeholder", bundle: .module), text: $inputText)
                    .textFieldStyle(.plain)
                    .focused($isInputFocused)
                    .onSubmit {
                        if !inputText.isEmpty {
                            addHabitFromInput()
                        }
                    }
                    .onChange(of: inputText) { _, newValue in
                        detectedType = detectHabitType(from: newValue)
                        updatePreviewHabit()
                    }
                
                if !inputText.isEmpty {
                    Button {
                        clearInput()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Button {
                    if inputText.isEmpty {
                        showingTypePicker = true
                    } else {
                        addHabitFromInput()
                    }
                } label: {
                    Image(systemName: inputText.isEmpty ? "plus.circle.fill" : "arrow.right.circle.fill")
                        .font(.title3)
                        .foregroundStyle(inputText.isEmpty ? Color.secondary : Color.blue)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
            
            // Live preview card
            if let preview = previewHabit, !inputText.isEmpty {
                PreviewCard(habit: preview) {
                    addHabitFromPreview(preview)
                }
                .transition(.scale.combined(with: .opacity))
            }
            
            // Smart suggestions
            if !inputText.isEmpty, let suggestions = getSmartSuggestions() {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(suggestions, id: \.0) { suggestion, type in
                            Button {
                                createHabit(name: suggestion, type: type)
                                clearInput()
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: type.iconName)
                                        .font(.caption)
                                    Text(suggestion)
                                        .font(.caption)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(.regularMaterial, in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingTypePicker) {
            HabitTypePickerView { type in
                let name = getDefaultName(for: type)
                createHabit(name: name, type: type)
            }
        }
    }
    
    // MARK: - Smart Detection
    
    private func detectHabitType(from text: String) -> HabitType? {
        let lowercased = text.lowercased()
        
        // Timer detection
        if lowercased.contains("min") || lowercased.contains("minute") || lowercased.contains("timer") {
            if let duration = extractDuration(from: text) {
                return .timer(style: .down, duration: duration)
            }
        }
        
        // Rest timer detection (convert to count-up timer)
        if lowercased.contains("rest") || lowercased.contains("break") || lowercased.contains("pause") {
            let duration = extractDuration(from: text) ?? 300 // Default 5 minutes
            return .timer(style: .up, duration: duration, target: duration)
        }
        
        // Shortcuts detection
        if lowercased.contains("shortcut") || lowercased.contains("run") || lowercased.contains("open") || lowercased.contains("launch") {
            // Extract potential shortcut name
            let words = text.components(separatedBy: .whitespacesAndNewlines.union(.punctuationCharacters))
                .filter { !$0.isEmpty }
                .filter { !["run", "open", "launch", "shortcut", "the", "my", "a", "an"].contains($0.lowercased()) }
            
            if let shortcutName = words.first {
                return .action(type: .shortcut, identifier: shortcutName, displayName: shortcutName.capitalized)
            }
        }
        
        // URL scheme detection
        if lowercased.contains("://") {
            // Extract URL scheme
            if let schemeRange = text.range(of: "://") {
                let urlScheme = String(text[..<schemeRange.upperBound])
                let appName = urlScheme.replacingOccurrences(of: "://", with: "").capitalized
                return .action(type: .app, identifier: urlScheme, displayName: appName)
            }
        }
        
        // Website detection
        if lowercased.contains("website") || lowercased.contains("http") || lowercased.contains("www") {
            return .action(type: .website, identifier: String(localized: "HabitTypePickerView.ExampleURL", bundle: .module), displayName: String(localized: "HabitQuickAddView.Website.Title", bundle: .module))
        }
        
        // Counter detection
        if lowercased.contains(":") || lowercased.contains(",") && lowercased.contains("supplement") {
            let items = extractListItems(from: text)
            if !items.isEmpty {
                return .tracking(.counter(items: items))
            }
        }
        
        // Measurement detection
        if lowercased.contains("measure") || lowercased.contains("weight") || lowercased.contains("kg") || lowercased.contains("lbs") {
            let unit = extractUnit(from: text) ?? "value"
            return .tracking(.measurement(unit: unit, targetValue: nil))
        }
        
        // Default to simple task
        return .task(subtasks: [])
    }
    
    private func extractDuration(from text: String) -> TimeInterval? {
        let pattern = #"(\d+)\s*(min|minute|m|hr|hour|h|sec|second|s)"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else {
            return nil
        }
        
        guard let valueRange = Range(match.range(at: 1), in: text),
              let value = Double(text[valueRange]),
              let unitRange = Range(match.range(at: 2), in: text) else {
            return nil
        }
        
        let unit = text[unitRange].lowercased()
        
        switch unit {
        case "s", "sec", "second":
            return value
        case "m", "min", "minute":
            return value * 60
        case "h", "hr", "hour":
            return value * 3600
        default:
            return value * 60 // Default to minutes
        }
    }
    
    private func extractListItems(from text: String) -> [String] {
        // Try colon format first: "Supplements: A, B, C"
        if let colonIndex = text.firstIndex(of: ":") {
            let itemsPart = text[text.index(after: colonIndex)...]
            return itemsPart.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        }
        
        // Try comma-separated
        let parts = text.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        if parts.count > 1 {
            return parts
        }
        
        return []
    }
    
    private func extractUnit(from text: String) -> String? {
        let units = ["kg", "lbs", "lb", "bpm", "%", "hours", "hr"]
        let lowercased = text.lowercased()
        
        for unit in units {
            if lowercased.contains(unit) {
                return unit
            }
        }
        
        return nil
    }
    
    
    // MARK: - Suggestions
    
    private func getSmartSuggestions() -> [(String, HabitType)]? {
        guard !inputText.isEmpty else { return nil }
        
        var suggestions: [(String, HabitType)] = []
        
        // Based on detected type
        if let type = detectedType {
            let cleanName = cleanHabitName(inputText)
            suggestions.append((cleanName, type))
            
            // Add variations
            switch type {
            case .timer(_, let duration, _, _):
                if duration != 300 {
                    suggestions.append((String(format: String(localized: "HabitQuickAddView.Suggestion.5min", bundle: .module), cleanName), .timer(style: .down, duration: 300)))
                }
                if duration != 600 {
                    suggestions.append((String(format: String(localized: "HabitQuickAddView.Suggestion.10min", bundle: .module), cleanName), .timer(style: .down, duration: 600)))
                }
            case .task(let subtasks):
                if subtasks.isEmpty {
                    suggestions.append((String(format: String(localized: "HabitQuickAddView.Suggestion.Task", bundle: .module), cleanName), .task(subtasks: [])))
                }
            default:
                break
            }
        }
        
        return suggestions.isEmpty ? nil : suggestions
    }
    
    private func cleanHabitName(_ text: String) -> String {
        var cleaned = text
        
        // Remove duration indicators
        let durationPattern = #"\s*\d+\s*(min|minute|m|hr|hour|h|sec|second|s)\s*"#
        if let regex = try? NSRegularExpression(pattern: durationPattern, options: .caseInsensitive) {
            cleaned = regex.stringByReplacingMatches(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned), withTemplate: "")
        }
        
        // Remove type indicators
        let typeWords = ["timer", "rest", "break", "measure", "open", "launch"]
        for word in typeWords {
            cleaned = cleaned.replacingOccurrences(of: word, with: "", options: .caseInsensitive)
        }
        
        // Clean up
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        cleaned = cleaned.replacingOccurrences(of: "  ", with: " ")
        
        // Capitalize first letter
        if !cleaned.isEmpty {
            cleaned = cleaned.prefix(1).uppercased() + cleaned.dropFirst()
        }
        
        return cleaned
    }
    
    // MARK: - Helpers
    
    private var detectedTypeIcon: String {
        detectedType?.iconName ?? "plus.circle"
    }
    
    private var detectedTypeColor: Color {
        detectedType != nil ? Color.blue : Color.secondary
    }
    
    private func updatePreviewHabit() {
        guard !inputText.isEmpty else {
            previewHabit = nil
            return
        }
        
        let name = cleanHabitName(inputText)
        let type = detectedType ?? .task(subtasks: [])
        previewHabit = Habit(
            name: name,
            type: type,
            color: getColorForType(type)
        )
    }
    
    private func addHabitFromInput() {
        let name = cleanHabitName(inputText)
        let type = detectedType ?? .task(subtasks: [])
        createHabit(name: name, type: type)
        clearInput()
    }
    
    private func addHabitFromPreview(_ habit: Habit) {
        onAdd(habit)
        clearInput()
    }
    
    private func clearInput() {
        inputText = ""
        detectedType = nil
        previewHabit = nil
    }
    
    private func createHabit(name: String, type: HabitType) {
        let habit = Habit(
            name: name,
            type: type,
            color: getColorForType(type)
        )
        onAdd(habit)
    }
    
    private func getColorForType(_ type: HabitType) -> String {
        switch type {
        case .task:
            return "#34C759" // Green
        case .timer:
            return "#007AFF" // Blue
        case .action:
            return "#FF3B30" // Red
        case .tracking(let trackingType):
            switch trackingType {
            case .counter:
                return "#FFD60A" // Yellow
            case .measurement:
                return "#BF5AF2" // Purple
            }
        case .guidedSequence:
            return "#64D2FF" // Light Blue
        case .conditional:
            return "#5856D6" // Indigo
        }
    }
    
    private func getDefaultName(for type: HabitType) -> String {
        switch type {
        case .task:
            return String(localized: "HabitQuickAddView.DefaultName.NewTask", bundle: .module)
        case .timer(let style, _, _, _):
            switch style {
            case .down:
                return String(localized: "HabitQuickAddView.DefaultName.TimedActivity", bundle: .module)
            case .up:
                return String(localized: "HabitQuickAddView.DefaultName.RestPeriod", bundle: .module)
            case .multiple:
                return String(localized: "HabitQuickAddView.DefaultName.MultipleTimers", bundle: .module)
            }
        case .action(let type, _, _):
            switch type {
            case .app:
                return String(localized: "HabitQuickAddView.DefaultName.LaunchApp", bundle: .module)
            case .website:
                return String(localized: "HabitQuickAddView.DefaultName.OpenWebsite", bundle: .module)
            case .shortcut:
                return String(localized: "HabitQuickAddView.DefaultName.RunShortcut", bundle: .module)
            }
        case .tracking(let trackingType):
            switch trackingType {
            case .counter:
                return String(localized: "HabitQuickAddView.DefaultName.TrackItems", bundle: .module)
            case .measurement:
                return String(localized: "HabitQuickAddView.DefaultName.RecordMeasurement", bundle: .module)
            }
        case .guidedSequence:
            return String(localized: "HabitQuickAddView.DefaultName.GuidedActivity", bundle: .module)
        case .conditional:
            return String(localized: "HabitQuickAddView.DefaultName.Question", bundle: .module)
        }
    }
}

// MARK: - Type Picker

private struct HabitTypePickerView: View {
    @Environment(\.dismiss) private var dismiss
    let onSelect: (HabitType) -> Void
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    TypeOptionRow(
                        icon: "checkmark.square",
                        title: String(localized: "HabitTypePickerView.Task.Title", bundle: .module),
                        description: String(localized: "HabitTypePickerView.Task.Description", bundle: .module),
                        color: .green
                    ) {
                        onSelect(.task(subtasks: []))
                        dismiss()
                    }
                }
                
                Section {
                    TypeOptionRow(
                        icon: "timer",
                        title: String(localized: "HabitTypePickerView.Timer.Title", bundle: .module),
                        description: String(localized: "HabitTypePickerView.Timer.Description", bundle: .module),
                        color: .blue
                    ) {
                        onSelect(.timer(style: .down, duration: 300))
                        dismiss()
                    }
                }
                
                Section {
                    TypeOptionRow(
                        icon: "app.badge",
                        title: String(localized: "HabitTypePickerView.ExternalAction.Title", bundle: .module),
                        description: String(localized: "HabitTypePickerView.ExternalAction.Description", bundle: .module),
                        color: .red
                    ) {
                        onSelect(.action(type: .app, identifier: "", displayName: String(localized: "HabitTypePickerView.Action.DefaultName", bundle: .module)))
                        dismiss()
                    }
                }
                
                Section {
                    TypeOptionRow(
                        icon: "list.bullet",
                        title: String(localized: "HabitTypePickerView.Tracking.Title", bundle: .module),
                        description: String(localized: "HabitTypePickerView.Tracking.Description", bundle: .module),
                        color: .orange
                    ) {
                        onSelect(.tracking(.counter(items: [String(localized: "HabitTypePickerView.CounterItem1", bundle: .module), String(localized: "HabitTypePickerView.CounterItem2", bundle: .module)])))
                        dismiss()
                    }
                    
                    TypeOptionRow(
                        icon: "list.number",
                        title: String(localized: "HabitTypePickerView.GuidedSequence.Title", bundle: .module),
                        description: String(localized: "HabitTypePickerView.GuidedSequence.Description", bundle: .module),
                        color: .cyan
                    ) {
                        onSelect(.guidedSequence(steps: []))
                        dismiss()
                    }
                    
                    TypeOptionRow(
                        icon: "questionmark.circle",
                        title: String(localized: "HabitTypePickerView.Question.Title", bundle: .module),
                        description: String(localized: "HabitTypePickerView.Question.Description", bundle: .module),
                        color: .indigo
                    ) {
                        onSelect(.conditional(ConditionalHabitInfo(question: "", options: [])))
                        dismiss()
                    }
                }
            }
            .navigationTitle(String(localized: "HabitTypePickerView.NavigationTitle", bundle: .module))
            
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "HabitTypePickerView.Cancel.Button", bundle: .module)) {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct TypeOptionRow: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                    .frame(width: 32)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview Card

private struct PreviewCard: View {
    let habit: Habit
    let onAdd: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: habit.type.iconName)
                .font(.body)
                .foregroundStyle(habit.swiftUIColor)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(habit.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(habit.type.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Text(habit.estimatedDuration.formattedDuration)
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    onAdd()
                }
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.white, .blue)
            }
            .accessibilityLabel(String(localized: "HabitQuickAddView.AddHabit.AccessibilityLabel", bundle: .module))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(habit.swiftUIColor.opacity(0.3), lineWidth: 1)
        )
    }
}

#Preview {
    VStack {
        HabitQuickAddView { habit in
            print("Added: \(habit.name)")
        }
        .padding()
        
        Spacer()
    }
}