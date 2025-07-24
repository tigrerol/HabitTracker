import SwiftUI

/// Quick add bar with smart type detection for creating habits
struct HabitQuickAddView: View {
    @State private var inputText = ""
    @State private var showingTypePicker = false
    @State private var detectedType: HabitType?
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
                
                TextField("Add a habit...", text: $inputText)
                    .textFieldStyle(.plain)
                    .focused($isInputFocused)
                    .onSubmit {
                        if !inputText.isEmpty {
                            addHabitFromInput()
                        }
                    }
                    .onChange(of: inputText) { _, newValue in
                        detectedType = detectHabitType(from: newValue)
                    }
                
                if !inputText.isEmpty {
                    Button {
                        inputText = ""
                        detectedType = nil
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
            
            // Smart suggestions
            if !inputText.isEmpty, let suggestions = getSmartSuggestions() {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(suggestions, id: \.0) { suggestion, type in
                            Button {
                                createHabit(name: suggestion, type: type)
                                inputText = ""
                                detectedType = nil
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
                return .timer(defaultDuration: duration)
            }
        }
        
        // Rest timer detection
        if lowercased.contains("rest") || lowercased.contains("break") || lowercased.contains("pause") {
            let duration = extractDuration(from: text)
            return .restTimer(targetDuration: duration)
        }
        
        // Shortcuts detection
        if lowercased.contains("shortcut") || lowercased.contains("run") || lowercased.contains("open") || lowercased.contains("launch") {
            // Extract potential shortcut name
            let words = text.components(separatedBy: .whitespacesAndNewlines.union(.punctuationCharacters))
                .filter { !$0.isEmpty }
                .filter { !["run", "open", "launch", "shortcut", "the", "my", "a", "an"].contains($0.lowercased()) }
            
            if let shortcutName = words.first {
                return .appLaunch(bundleId: shortcutName, appName: shortcutName.capitalized)
            }
        }
        
        // URL scheme detection
        if lowercased.contains("://") {
            // Extract URL scheme
            if let schemeRange = text.range(of: "://") {
                let urlScheme = String(text[..<schemeRange.upperBound])
                let appName = urlScheme.replacingOccurrences(of: "://", with: "").capitalized
                return .appLaunch(bundleId: urlScheme, appName: appName)
            }
        }
        
        // Website detection
        if lowercased.contains("website") || lowercased.contains("http") || lowercased.contains("www") {
            return .website(url: URL(string: "https://example.com")!, title: "Website")
        }
        
        // Counter detection
        if lowercased.contains(":") || lowercased.contains(",") && lowercased.contains("supplement") {
            let items = extractListItems(from: text)
            if !items.isEmpty {
                return .counter(items: items)
            }
        }
        
        // Measurement detection
        if lowercased.contains("measure") || lowercased.contains("weight") || lowercased.contains("kg") || lowercased.contains("lbs") {
            let unit = extractUnit(from: text) ?? "value"
            return .measurement(unit: unit, targetValue: nil)
        }
        
        // Subtasks detection
        if lowercased.contains("routine") || lowercased.contains("prep") || text.contains("->") {
            return .checkboxWithSubtasks(subtasks: [])
        }
        
        // Default to checkbox
        return .checkbox
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
            case .timer(let duration):
                if duration != 300 {
                    suggestions.append(("\(cleanName) (5 min)", .timer(defaultDuration: 300)))
                }
                if duration != 600 {
                    suggestions.append(("\(cleanName) (10 min)", .timer(defaultDuration: 600)))
                }
            case .checkbox:
                suggestions.append(("\(cleanName) checklist", .checkboxWithSubtasks(subtasks: [])))
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
    
    private func addHabitFromInput() {
        let name = cleanHabitName(inputText)
        let type = detectedType ?? .checkbox
        createHabit(name: name, type: type)
        inputText = ""
        detectedType = nil
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
        case .checkbox, .checkboxWithSubtasks:
            return "#34C759" // Green
        case .timer, .restTimer:
            return "#007AFF" // Blue
        case .appLaunch:
            return "#FF3B30" // Red
        case .website:
            return "#FF9500" // Orange
        case .counter:
            return "#FFD60A" // Yellow
        case .measurement:
            return "#BF5AF2" // Purple
        case .guidedSequence:
            return "#64D2FF" // Light Blue
        }
    }
    
    private func getDefaultName(for type: HabitType) -> String {
        switch type {
        case .checkbox:
            return "New Task"
        case .checkboxWithSubtasks:
            return "Task with Steps"
        case .timer:
            return "Timed Activity"
        case .restTimer:
            return "Rest Period"
        case .appLaunch:
            return "Run Shortcut"
        case .website:
            return "Visit Website"
        case .counter:
            return "Track Items"
        case .measurement:
            return "Record Measurement"
        case .guidedSequence:
            return "Guided Activity"
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
                        title: "Simple Task",
                        description: "Tap to complete",
                        color: .green
                    ) {
                        onSelect(.checkbox)
                        dismiss()
                    }
                    
                    TypeOptionRow(
                        icon: "checklist",
                        title: "Task with Subtasks",
                        description: "Break down into steps",
                        color: .green
                    ) {
                        onSelect(.checkboxWithSubtasks(subtasks: []))
                        dismiss()
                    }
                }
                
                Section {
                    TypeOptionRow(
                        icon: "timer",
                        title: "Timer",
                        description: "Count down from set time",
                        color: .blue
                    ) {
                        onSelect(.timer(defaultDuration: 300))
                        dismiss()
                    }
                    
                    
                    TypeOptionRow(
                        icon: "pause.circle",
                        title: "Rest Timer",
                        description: "Count up to track rest",
                        color: .blue
                    ) {
                        onSelect(.restTimer(targetDuration: 120))
                        dismiss()
                    }
                }
                
                Section {
                    TypeOptionRow(
                        icon: "shortcuts",
                        title: "Run Shortcut",
                        description: "Execute a Shortcuts shortcut or open app via URL",
                        color: .red
                    ) {
                        onSelect(.appLaunch(bundleId: "", appName: "Shortcut"))
                        dismiss()
                    }
                    
                    TypeOptionRow(
                        icon: "safari",
                        title: "Open Website",
                        description: "Visit a URL",
                        color: .orange
                    ) {
                        onSelect(.website(url: URL(string: "https://example.com")!, title: "Website"))
                        dismiss()
                    }
                }
                
                Section {
                    TypeOptionRow(
                        icon: "list.bullet",
                        title: "Checklist",
                        description: "Track multiple items",
                        color: .yellow
                    ) {
                        onSelect(.counter(items: ["Item 1", "Item 2"]))
                        dismiss()
                    }
                    
                    TypeOptionRow(
                        icon: "chart.line.uptrend.xyaxis",
                        title: "Measurement",
                        description: "Record a value",
                        color: .purple
                    ) {
                        onSelect(.measurement(unit: "value", targetValue: nil))
                        dismiss()
                    }
                    
                    TypeOptionRow(
                        icon: "list.number",
                        title: "Guided Sequence",
                        description: "Step-by-step instructions",
                        color: .cyan
                    ) {
                        onSelect(.guidedSequence(steps: []))
                        dismiss()
                    }
                }
            }
            .navigationTitle("Choose Habit Type")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
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

#Preview {
    VStack {
        HabitQuickAddView { habit in
            print("Added: \(habit.name)")
        }
        .padding()
        
        Spacer()
    }
}