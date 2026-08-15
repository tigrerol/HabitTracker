import Foundation

/// A temporary life phase — vacation, sick day, business trip — that narrows the
/// Today list to a hand-picked set of routines.
///
/// Modes deliberately sit *outside* the context engine (`RoutineContextRule`):
/// context rules answer "which routine fits right now", a mode answers "which
/// routines exist at all right now". Inside a mode, routines are still scored
/// and sorted by context exactly as before.
public struct RoutineMode: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    /// SF Symbol name shown in the Today chip and the mode list.
    public var icon: String
    /// Templates visible while this mode is active.
    public var templateIds: Set<UUID>
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        icon: String = "beach.umbrella.fill",
        templateIds: Set<UUID> = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.templateIds = templateIds
        self.createdAt = createdAt
    }
}

extension RoutineMode {
    /// Starting points offered when the user adds their first modes.
    public static let suggestions: [(name: String, icon: String)] = [
        ("Vacation", "beach.umbrella.fill"),
        ("Sick Day", "thermometer.medium"),
        ("Travel", "airplane"),
        ("Light Week", "tortoise.fill")
    ]

    /// Icons offered in the mode editor.
    public static let iconChoices: [String] = [
        "beach.umbrella.fill",
        "airplane",
        "thermometer.medium",
        "tortoise.fill",
        "sun.horizon.fill",
        "tent.fill",
        "mountain.2.fill",
        "figure.walk",
        "cup.and.saucer.fill",
        "moon.zzz.fill",
        "heart.fill",
        "star.fill"
    ]
}

/// Persisted mode list plus which one (if any) is currently active.
public struct RoutineModeSettings: Codable, Sendable {
    public var modes: [RoutineMode]
    public var activeModeId: UUID?

    public init(modes: [RoutineMode] = [], activeModeId: UUID? = nil) {
        self.modes = modes
        self.activeModeId = activeModeId
    }

    public static let empty = RoutineModeSettings()
}
