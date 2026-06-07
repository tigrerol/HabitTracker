import Foundation

/// AI-facing DTO for importing a single routine.
///
/// Decoupled from `RoutineTemplate` so the schema we hand to an LLM stays
/// small, stable, and ergonomic even as internal models evolve. Translated
/// into `RoutineTemplate` by `RoutineImportService`.
public struct RoutineImportDTO: Codable, Sendable {
    public var name: String
    public var description: String?
    public var color: String?
    public var habits: [HabitImportDTO]
}

public struct HabitImportDTO: Codable, Sendable {
    public var name: String
    public var type: HabitImportTypeDTO
    public var isOptional: Bool?
    public var notes: String?
    public var color: String?

    // task
    public var subtasks: [String]?
    public var estimatedSeconds: Double?

    // timer
    public var timer: TimerImportDTO?

    // tracking
    public var tracking: TrackingImportDTO?

    // guidedSequence
    public var steps: [SequenceStepImportDTO]?

    // website
    public var url: String?

    // shortcut
    public var shortcutName: String?

    // shared display name for website/shortcut
    public var displayName: String?
}

public enum HabitImportTypeDTO: String, Codable, Sendable {
    case task
    case timer
    case tracking
    case guidedSequence
    case website
    case shortcut
}

public struct TimerImportDTO: Codable, Sendable {
    public var style: TimerStyleDTO
    public var durationSeconds: Double?
    public var targetSeconds: Double?
    public var steps: [SequenceStepImportDTO]?
    public var repeatCount: Int?
}

public enum TimerStyleDTO: String, Codable, Sendable {
    case down
    case up
    case multiple
}

public struct TrackingImportDTO: Codable, Sendable {
    public var kind: TrackingKindDTO
    public var items: [String]?
    public var unit: String?
    public var targetValue: Double?
}

public enum TrackingKindDTO: String, Codable, Sendable {
    case counter
    case measurement
}

public struct SequenceStepImportDTO: Codable, Sendable {
    public var name: String
    public var durationSeconds: Double
    public var instructions: String?
}
