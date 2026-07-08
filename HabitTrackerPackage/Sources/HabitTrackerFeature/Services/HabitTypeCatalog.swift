import SwiftUI

/// Display metadata for a creatable habit type in builder UIs.
struct HabitTypeOption {
    let name: String
    let description: String
    let type: HabitType
    let color: Color
}

/// Catalog of creatable habit types plus factory defaults (name/color) for
/// freshly created habits. Single source of truth for the builder's type
/// picker cards — previously duplicated inside RoutineBuilderView.
enum HabitTypeCatalog {

    static var basicOptions: [HabitTypeOption] {
        [
            HabitTypeOption(
                name: String(localized: "HabitType.Task.Name", bundle: .module),
                description: String(localized: "HabitType.Task.Description", bundle: .module),
                type: .task(subtasks: []),
                color: .green
            ),
            HabitTypeOption(
                name: String(localized: "HabitType.Timer.Name", bundle: .module),
                description: String(localized: "HabitType.Timer.Description", bundle: .module),
                type: .timer(style: .down, duration: 300),
                color: .blue
            ),
            HabitTypeOption(
                name: String(localized: "HabitType.Action.Name", bundle: .module),
                description: String(localized: "HabitType.Action.Description", bundle: .module),
                type: .action(type: .app, identifier: "", displayName: ""),
                color: .red
            ),
            HabitTypeOption(
                name: String(localized: "HabitType.Tracking.Name", bundle: .module),
                description: String(localized: "HabitType.Tracking.Description", bundle: .module),
                type: .tracking(.counter(items: ["Item 1"])),
                color: .orange
            )
        ]
    }

    /// Optional-typed so callers can gate the question card if conditional
    /// habits are ever disabled; currently always present.
    static var questionOption: HabitTypeOption? {
        HabitTypeOption(
            name: "Question",
            description: "Conditional path",
            type: .conditional(ConditionalHabitInfo(
                question: "",
                options: [
                    ConditionalOption(text: "Yes", habits: []),
                    ConditionalOption(text: "No", habits: [])
                ]
            )),
            color: .indigo
        )
    }

    /// Create a habit of the given type with sensible default name and color.
    static func makeHabit(ofType type: HabitType) -> Habit {
        Habit(
            name: defaultName(for: type),
            type: type,
            color: defaultColor(for: type)
        )
    }

    static func defaultName(for type: HabitType) -> String {
        switch type {
        case .task:
            return "New Task"
        case .timer(let style, _, _, _, _):
            switch style {
            case .down: return "Timed Activity"
            case .up: return "Rest Period"
            case .multiple: return "Multiple Timers"
            }
        case .action(let type, _, _, _):
            switch type {
            case .app:
                return "Launch App"
            case .website:
                return "Open Website"
            case .shortcut:
                return "Run Shortcut"
            }
        case .tracking(let trackingType):
            switch trackingType {
            case .counter:
                return "Track Items"
            case .measurement:
                return "Record Measurement"
            }
        case .guidedSequence:
            return "Guided Activity"
        case .conditional:
            return "Question"
        }
    }

    static func defaultColor(for type: HabitType) -> String {
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
}
