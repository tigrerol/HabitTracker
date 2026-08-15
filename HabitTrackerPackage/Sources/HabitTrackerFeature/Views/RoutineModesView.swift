import SwiftUI

/// Manage routine modes — temporary phases (Vacation, Sick Day, …) that narrow
/// the Today list to a hand-picked set of routines.
struct RoutineModesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(RoutineService.self) private var routineService
    @Environment(RoutineModeService.self) private var modeService
    @Environment(ThemeManager.self) private var themeManager

    @State private var editingMode: NewOrExistingMode?

    var body: some View {
        NavigationStack {
            List {
                if modeService.modes.isEmpty {
                    Section {
                        Text("A mode hides the routines you don't need right now. Turn one on when you go on vacation, catch a cold, or travel for work — and off again when normal life resumes.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section {
                        ForEach(modeService.modes) { mode in
                            modeRow(mode)
                        }
                        .onDelete(perform: deleteModes)
                    } header: {
                        Text("Your Modes")
                    } footer: {
                        Text("Only one mode can be active at a time. While a mode is active, the Today tab and the widget show only its routines.")
                    }
                }

                Section {
                    ForEach(RoutineMode.suggestions, id: \.name) { suggestion in
                        if !modeService.modes.contains(where: { $0.name == suggestion.name }) {
                            Button {
                                editingMode = NewOrExistingMode(mode: RoutineMode(name: suggestion.name, icon: suggestion.icon), isNew: true)
                            } label: {
                                Label(suggestion.name, systemImage: suggestion.icon)
                            }
                        }
                    }

                    Button {
                        editingMode = NewOrExistingMode(mode: RoutineMode(name: "", icon: "star.fill"), isNew: true)
                    } label: {
                        Label("Custom Mode", systemImage: "plus.circle")
                    }
                } header: {
                    Text("Add a Mode")
                }
            }
            .scrollContentBackground(.hidden)
            .appBackground()
            .navigationTitle("Routine Modes")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $editingMode) { item in
                RoutineModeEditorView(mode: item.mode, isNew: item.isNew)
                    .environment(routineService)
                    .environment(modeService)
            }
        }
    }

    private func modeRow(_ mode: RoutineMode) -> some View {
        let isActive = modeService.activeModeId == mode.id
        let count = modeService.templateCount(for: mode, in: routineService.templates)

        return Button {
            editingMode = NewOrExistingMode(mode: mode, isNew: false)
        } label: {
            HStack {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(mode.name)
                            .foregroundStyle(.primary)
                            .fontWeight(.medium)

                        Text(count == 1 ? "1 routine" : "\(count) routines")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: mode.icon)
                        .foregroundStyle(isActive ? themeManager.currentAccentColor : .secondary)
                        .frame(width: 24)
                }

                Spacer()

                if isActive {
                    Text("Active")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(themeManager.currentAccentColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(themeManager.currentAccentColor.opacity(0.15)))
                }

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(mode.name), \(count) routines\(isActive ? ", active" : "")")
    }

    private func deleteModes(at offsets: IndexSet) {
        for index in offsets {
            modeService.deleteMode(withId: modeService.modes[index].id)
        }
    }
}

// MARK: - Editor

/// Create or edit a single mode: name, icon, and which routines it shows.
struct RoutineModeEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(RoutineService.self) private var routineService
    @Environment(RoutineModeService.self) private var modeService
    @Environment(ThemeManager.self) private var themeManager

    @State private var name: String
    @State private var icon: String
    @State private var templateIds: Set<UUID>

    private let mode: RoutineMode
    private let isNew: Bool

    init(mode: RoutineMode, isNew: Bool) {
        self.mode = mode
        self.isNew = isNew
        _name = State(initialValue: mode.name)
        _icon = State(initialValue: mode.icon)
        _templateIds = State(initialValue: mode.templateIds)
    }

    private var isActive: Bool { modeService.activeModeId == mode.id }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool { !trimmedName.isEmpty }

    var body: some View {
        NavigationStack {
            List {
                Section("Name") {
                    TextField("Mode name", text: $name)
                        .textInputAutocapitalization(.words)
                }

                Section("Icon") {
                    iconGrid
                }

                Section {
                    if routineService.templates.isEmpty {
                        Text("No routines yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(routineService.templates) { template in
                            templateRow(template)
                        }
                    }
                } header: {
                    Text("Show These Routines")
                } footer: {
                    Text(templateIds.isEmpty
                         ? "Pick at least one routine — an empty mode would leave the Today tab with nothing to show, so it falls back to showing everything."
                         : "Everything else is hidden from Today while this mode is active.")
                }

                if !isNew {
                    Section {
                        Button(isActive ? "Turn Off \(trimmedName)" : "Turn On \(trimmedName)") {
                            save()
                            if isActive {
                                modeService.deactivate()
                            } else {
                                modeService.activate(modeId: mode.id)
                            }
                            dismiss()
                        }
                        .disabled(!canSave)

                        Button("Delete Mode", role: .destructive) {
                            modeService.deleteMode(withId: mode.id)
                            dismiss()
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .appBackground()
            .navigationTitle(isNew ? "New Mode" : trimmedName)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isNew ? "Add" : "Save") {
                        save()
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private var iconGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 52), spacing: 12)], spacing: 12) {
            ForEach(RoutineMode.iconChoices, id: \.self) { choice in
                Button {
                    icon = choice
                } label: {
                    Image(systemName: choice)
                        .font(.title3)
                        .frame(width: 44, height: 44)
                        .foregroundStyle(icon == choice ? themeManager.currentAccentColor : .secondary)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(icon == choice ? themeManager.currentAccentColor.opacity(0.15) : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(icon == choice ? themeManager.currentAccentColor.opacity(0.5) : Theme.hairline, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(choice)
                .accessibilityAddTraits(icon == choice ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(.vertical, 4)
    }

    private func templateRow(_ template: RoutineTemplate) -> some View {
        let isIncluded = templateIds.contains(template.id)

        return Button {
            if isIncluded {
                templateIds.remove(template.id)
            } else {
                templateIds.insert(template.id)
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(template.name)
                        .foregroundStyle(.primary)
                    Text("\(template.activeHabitsCount) habits • \(template.formattedDuration)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: isIncluded ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isIncluded ? AnyShapeStyle(themeManager.currentAccentColor) : AnyShapeStyle(.tertiary))
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(template.name)
        .accessibilityAddTraits(isIncluded ? [.isButton, .isSelected] : .isButton)
    }

    private func save() {
        guard canSave else { return }
        var updated = mode
        updated.name = trimmedName
        updated.icon = icon
        updated.templateIds = templateIds

        if isNew {
            modeService.addMode(updated)
        } else {
            modeService.updateMode(updated)
        }
    }
}

/// Sheet payload — a mode plus whether it exists yet, so the editor doesn't
/// have to guess against a possibly-injected service.
private struct NewOrExistingMode: Identifiable {
    let mode: RoutineMode
    let isNew: Bool
    var id: UUID { mode.id }
}

#Preview {
    RoutineModesView()
        .environment(RoutineService())
        .environment(RoutineModeService())
        .withDynamicTheme()
}
