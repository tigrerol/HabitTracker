import Foundation
#if targetEnvironment(macCatalyst)
import Security
#endif

public enum WidgetSharedConstants {
    public static let appGroupIdentifier = "group.com.tigrerol.habittracker"
    public static let snapshotFileName = "widget_snapshot.json"

    /// Locate the shared container, working on both iOS and Mac Catalyst.
    ///
    /// macOS app groups are team-prefixed (`ABCDE12345.group.foo`) while iOS
    /// uses the bare identifier, so one string can't serve both. Rather than
    /// hardcode a team ID, the Mac build reads the group out of the entitlements
    /// the binary was actually signed with — exact by construction, and it keeps
    /// working if the signing team ever changes.
    ///
    /// Candidates are tried in order and the first that resolves wins, so a
    /// wrong guess degrades to "try the other one" rather than a missing
    /// container.
    public static func containerURL(forAppGroup identifier: String) -> URL? {
        for candidate in containerCandidates(for: identifier) {
            if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: candidate) {
                return url
            }
        }
        return nil
    }

    static func containerCandidates(for identifier: String) -> [String] {
        #if targetEnvironment(macCatalyst)
        // Prefer a signed group that matches this identifier — bare on the
        // off-chance macOS ever stops prefixing, prefixed as it works today.
        let signed = signedAppGroups().filter {
            $0 == identifier || $0.hasSuffix("." + identifier)
        }
        return signed + [identifier]
        #else
        return [identifier]
        #endif
    }

    #if targetEnvironment(macCatalyst)
    /// The `com.apple.security.application-groups` entitlement of the running
    /// binary, with `$(TeamIdentifierPrefix)` already expanded by codesign.
    static func signedAppGroups() -> [String] {
        guard let task = SecTaskCreateFromSelf(nil),
              let value = SecTaskCopyValueForEntitlement(
                  task,
                  "com.apple.security.application-groups" as CFString,
                  nil
              ) as? [String]
        else { return [] }
        return value
    }
    #endif
}

public struct WidgetSnapshot: Codable, Sendable, Equatable {
    public struct TopRoutine: Codable, Sendable, Equatable {
        public let name: String
        public let habitCount: Int
        public let colorHex: String
        /// Optional so snapshots written before deep links existed still decode.
        public let templateId: UUID?

        public init(name: String, habitCount: Int, colorHex: String, templateId: UUID? = nil) {
            self.name = name
            self.habitCount = habitCount
            self.colorHex = colorHex
            self.templateId = templateId
        }
    }

    public struct PausedSession: Codable, Sendable, Equatable {
        public let routineName: String
        public let pausedAt: Date
        public let currentStepIndex: Int
        public let totalSteps: Int
        /// Optional so snapshots written before deep links existed still decode.
        public let sessionId: UUID?

        public init(routineName: String, pausedAt: Date, currentStepIndex: Int, totalSteps: Int, sessionId: UUID? = nil) {
            self.routineName = routineName
            self.pausedAt = pausedAt
            self.currentStepIndex = currentStepIndex
            self.totalSteps = totalSteps
            self.sessionId = sessionId
        }
    }

    public struct StreakEntry: Codable, Sendable, Equatable {
        public let routineName: String
        public let totalStreak: Int
        public let target: Int
        public let completedThisWeek: Int

        public init(routineName: String, totalStreak: Int, target: Int, completedThisWeek: Int) {
            self.routineName = routineName
            self.totalStreak = totalStreak
            self.target = target
            self.completedThisWeek = completedThisWeek
        }
    }

    public let generatedAt: Date
    public let topRoutine: TopRoutine?
    public let pausedSession: PausedSession?
    public let streaks: [StreakEntry]

    public init(
        generatedAt: Date,
        topRoutine: TopRoutine?,
        pausedSession: PausedSession?,
        streaks: [StreakEntry]
    ) {
        self.generatedAt = generatedAt
        self.topRoutine = topRoutine
        self.pausedSession = pausedSession
        self.streaks = streaks
    }

    public static let empty = WidgetSnapshot(
        generatedAt: .distantPast,
        topRoutine: nil,
        pausedSession: nil,
        streaks: []
    )
}
