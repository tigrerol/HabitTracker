import Foundation

/// A live reference from a wrapper routine to another routine.
///
/// "Morning Vacation" includes "Core Morning" instead of copying its habits, so
/// editing Core Morning updates every wrapper that includes it. Includes are
/// expanded into a flat habit list at session start (`RoutineComposer`), which
/// keeps the execution engine, snapshots, streaks, and the widget unchanged.
///
/// `order` shares one numbering space with `Habit.order` inside the owning
/// template, so a block can sit between two loose habits.
public struct RoutineInclude: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    /// The routine whose habits get spliced in.
    public var templateId: UUID
    public var order: Int
    public var isActive: Bool

    public init(
        id: UUID = UUID(),
        templateId: UUID,
        order: Int = 0,
        isActive: Bool = true
    ) {
        self.id = id
        self.templateId = templateId
        self.order = order
        self.isActive = isActive
    }
}
