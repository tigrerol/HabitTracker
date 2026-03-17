#if canImport(WatchConnectivity)
import WatchConnectivity
#endif
import Foundation

// MARK: - Data Transfer Objects for Watch Communication

/// Simple DTO for transferring routine completion data from watch
public struct WatchRoutineCompletion: Codable, Sendable {
    public let id: UUID
    public let routineId: UUID
    public let routineName: String
    public let startedAt: Date
    public let completedAt: Date?
    public let habitCompletions: [WatchHabitCompletion]
    public let isCompleted: Bool
    
    public init(
        id: UUID = UUID(),
        routineId: UUID,
        routineName: String,
        startedAt: Date = Date(),
        completedAt: Date? = nil,
        habitCompletions: [WatchHabitCompletion] = [],
        isCompleted: Bool = false
    ) {
        self.id = id
        self.routineId = routineId
        self.routineName = routineName
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.habitCompletions = habitCompletions
        self.isCompleted = isCompleted
    }
}

/// Simple DTO for transferring habit completion data from watch
public struct WatchHabitCompletion: Codable, Sendable {
    public let id: UUID
    public let habitId: UUID
    public let habitName: String
    public let completedAt: Date
    public let timeTaken: TimeInterval?
    public let notes: String?
    public let wasSkipped: Bool
    
    public init(
        id: UUID = UUID(),
        habitId: UUID,
        habitName: String,
        completedAt: Date = Date(),
        timeTaken: TimeInterval? = nil,
        notes: String? = nil,
        wasSkipped: Bool = false
    ) {
        self.id = id
        self.habitId = habitId
        self.habitName = habitName
        self.completedAt = completedAt
        self.timeTaken = timeTaken
        self.notes = notes
        self.wasSkipped = wasSkipped
    }
}

#if canImport(WatchConnectivity)
@Observable
public final class WatchConnectivityManager: NSObject, Sendable, WCSessionDelegate {
    public static let shared = WatchConnectivityManager()
    
    @MainActor
    public var isReachable: Bool = false
    
    private override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }
    
    // MARK: - WCSessionDelegate
    
    public nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        let sessionIsReachable = session.isReachable
        let activationStateValue = activationState.rawValue
        
        Task { @MainActor in
            if let error = error {
                LoggingService.shared.error("WCSession activation failed: \(error.localizedDescription)", category: .app)
                return
            }
            LoggingService.shared.debug("WCSession activated with state: \(activationStateValue)", category: .app)
            isReachable = sessionIsReachable
        }
    }
    
    public nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        Task { @MainActor in
            LoggingService.shared.debug("WCSession became inactive", category: .app)
            isReachable = false
        }
    }

    public nonisolated func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }

    public nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let sessionIsReachable = session.isReachable

        Task { @MainActor in
            isReachable = sessionIsReachable
            LoggingService.shared.debug("Watch reachability changed: \(isReachable)", category: .app)
        }
    }

    public nonisolated func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        // Handle incoming messages from Watch
    }
    
    public nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        // Extract data outside of Task to avoid data race
        let completionData = userInfo["completion"] as? Data
        
        Task { @MainActor in
            LoggingService.shared.debug("Received user info from Watch", category: .app)

            // Handle routine completion from watch
            if let completionData = completionData {
                do {
                    let decoder = JSONDecoder()
                    let watchCompletion = try decoder.decode(WatchRoutineCompletion.self, from: completionData)

                    // Process the received completion
                    await processWatchCompletion(watchCompletion)

                    LoggingService.shared.info("Successfully processed routine completion from Watch: \(watchCompletion.routineName)", category: .app)
                } catch {
                    LoggingService.shared.error("Error decoding routine completion from Watch: \(error.localizedDescription)", category: .app)
                }
            }
        }
    }
    
    // MARK: - Process Watch Data
    
    private func processWatchCompletion(_ completion: WatchRoutineCompletion) async {
        // In a production app, you might want to:
        // 1. Save the completion to the iOS app's database
        // 2. Update analytics or statistics
        // 3. Trigger notifications or badges
        // 4. Sync with cloud services

        // TODO: Integrate with iOS app's routine tracking system
    }
    
    public nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        guard !applicationContext.isEmpty else { return }
    }

    public nonisolated func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: Error?) {
        // File transfer completed
    }
    
    // MARK: - Sending Data to Watch
    
    public func sendRoutineDataToWatch(_ routineTemplates: [RoutineTemplate]) {
        guard WCSession.default.activationState == .activated else { return }

        do {
            let encoder = JSONEncoder()
            let routineData = try encoder.encode(routineTemplates)
            let userInfo: [String: Any] = ["routines": routineData]
            WCSession.default.transferUserInfo(userInfo)
        } catch {
            // Encoding failed silently
        }
    }

    func sendSingleRoutineToWatch(_ routine: RoutineTemplate) {
        guard WCSession.default.activationState == .activated else { return }

        do {
            let encoder = JSONEncoder()
            let routineData = try encoder.encode(routine)
            let userInfo: [String: Any] = ["routine": routineData]
            WCSession.default.transferUserInfo(userInfo)
        } catch {
            // Encoding failed silently
        }
    }

    func requestWatchSync() {
        guard WCSession.default.activationState == .activated else { return }

        let message: [String: Any] = ["action": "sync_request"]

        if WCSession.default.isReachable {
            WCSession.default.sendMessage(message, replyHandler: nil) { _ in
            }
        } else {
            WCSession.default.transferUserInfo(message)
        }
    }
}
#endif