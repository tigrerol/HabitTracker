import WatchConnectivity
import Foundation
import SwiftData

// MARK: - Data Transfer Objects for iOS Communication

/// Simple DTO for transferring routine completion data to iOS
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

/// Simple DTO for transferring habit completion data to iOS
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

@Observable
@MainActor
final class WatchConnectivityManager: NSObject, WCSessionDelegate {
    static let shared = WatchConnectivityManager()
    
    var isConnected: Bool = false
    var routines: [RoutineTemplate] = []
    
    private var modelContext: ModelContext?
    
    private override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }
    
    // MARK: - WCSessionDelegate
    
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            if let error = error {
                print("WCSession activation failed with error: \(error.localizedDescription)")
                return
            }
            print("WCSession activated with state: \(activationState.rawValue)")
            isConnected = session.isReachable
        }
    }
    
    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            isConnected = session.isReachable
            print("iPhone reachability changed: \(isConnected)")
            
            // Notify offline queue manager about connectivity change
            OfflineQueueManager.shared.onConnectivityChanged(isConnected: isConnected)
        }
    }
    
    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        Task { @MainActor in
            print("Received user info from iOS: \(userInfo)")
            
            // Handle multiple routines
            if let routinesData = userInfo["routines"] as? Data {
                do {
                    let decoder = JSONDecoder()
                    let receivedRoutines = try decoder.decode([RoutineTemplate].self, from: routinesData)
                    await processReceivedRoutines(receivedRoutines)
                    print("Successfully processed \(receivedRoutines.count) routines.")
                } catch {
                    print("Error decoding routines data: \(error.localizedDescription)")
                }
            }
            
            // Handle single routine
            if let routineData = userInfo["routine"] as? Data {
                do {
                    let decoder = JSONDecoder()
                    let routine = try decoder.decode(RoutineTemplate.self, from: routineData)
                    await processSingleRoutine(routine)
                    print("Successfully processed routine: \(routine.name)")
                } catch {
                    print("Error decoding routine data: \(error.localizedDescription)")
                }
            }
            
            // Handle sync request
            if let action = userInfo["action"] as? String, action == "sync_request" {
                // Send back current watch state if needed
                print("Received sync request from iOS")
            }
        }
    }
    
    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        Task { @MainActor in
            print("Received application context from iOS: \(applicationContext)")
        }
    }
    
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        Task { @MainActor in
            print("Received message from iOS: \(message)")
        }
    }
    
    nonisolated func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: Error?) {
        if let error = error {
            print("File transfer failed with error: \(error.localizedDescription)")
            return
        }
        print("File transfer finished: \(fileTransfer.file.fileURL.lastPathComponent ?? "unknown file")")
    }
    
    // MARK: - Data Processing
    
    private func processReceivedRoutines(_ receivedRoutines: [RoutineTemplate]) async {
        guard let context = modelContext else {
            print("ModelContext not set. Cannot save routines.")
            return
        }
        
        // Clear existing routines and add new ones
        let descriptor = FetchDescriptor<PersistedRoutineTemplate>()
        do {
            let existingRoutines = try context.fetch(descriptor)
            for routine in existingRoutines {
                context.delete(routine)
            }
            
            for routine in receivedRoutines {
                let persistedRoutine = PersistedRoutineTemplate(from: routine)
                context.insert(persistedRoutine)
            }
            
            try context.save()
            
            // Update local routines array
            routines = receivedRoutines
            
        } catch {
            print("Error saving routines to SwiftData: \(error.localizedDescription)")
        }
    }
    
    private func processSingleRoutine(_ routine: RoutineTemplate) async {
        guard let context = modelContext else {
            print("ModelContext not set. Cannot save routine.")
            return
        }
        
        do {
            // Check if routine already exists
            let descriptor = FetchDescriptor<PersistedRoutineTemplate>(
                predicate: #Predicate { $0.id == routine.id }
            )
            let existingRoutines = try context.fetch(descriptor)
            
            // Remove existing routine if found
            if let existingRoutine = existingRoutines.first {
                context.delete(existingRoutine)
            }
            
            // Add the new/updated routine
            let persistedRoutine = PersistedRoutineTemplate(from: routine)
            context.insert(persistedRoutine)
            try context.save()
            
            // Update local routines array
            loadRoutinesFromStorage()
            
        } catch {
            print("Error saving routine to SwiftData: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Data Loading
    
    func loadRoutinesFromStorage() {
        guard let context = modelContext else {
            print("ModelContext not set. Cannot load routines.")
            return
        }
        
        do {
            let descriptor = FetchDescriptor<PersistedRoutineTemplate>()
            let persistedRoutines = try context.fetch(descriptor)
            routines = persistedRoutines.map { $0.toDomainModel() }
        } catch {
            print("Error loading routines from SwiftData: \(error.localizedDescription)")
            routines = []
        }
    }
    
    // MARK: - Communication with iOS
    
    func sendCompletionToiOS(_ completion: RoutineSession) {
        guard WCSession.default.activationState == .activated else {
            print("WCSession is not activated. Queueing completion for later.")
            OfflineQueueManager.shared.queueCompletion(completion)
            return
        }
        
        // If not connected, queue the completion
        guard isConnected else {
            print("iPhone not reachable. Queueing completion for later.")
            OfflineQueueManager.shared.queueCompletion(completion)
            return
        }
        
        do {
            // Convert RoutineSession to WatchRoutineCompletion DTO
            let watchHabitCompletions = completion.habitCompletions.map { habitCompletion in
                WatchHabitCompletion(
                    id: habitCompletion.id,
                    habitId: habitCompletion.habitId,
                    habitName: habitCompletion.habitName,
                    completedAt: habitCompletion.completedAt,
                    timeTaken: habitCompletion.timeTaken,
                    notes: habitCompletion.notes,
                    wasSkipped: habitCompletion.wasSkipped
                )
            }
            
            let watchCompletion = WatchRoutineCompletion(
                id: completion.id,
                routineId: completion.routineId,
                routineName: completion.routineName,
                startedAt: completion.startedAt,
                completedAt: completion.completedAt,
                habitCompletions: watchHabitCompletions,
                isCompleted: completion.isCompleted
            )
            
            let encoder = JSONEncoder()
            let completionData = try encoder.encode(watchCompletion)
            let userInfo: [String: Any] = ["completion": completionData]
            
            WCSession.default.transferUserInfo(userInfo)
            print("Sent routine completion to iOS.")
        } catch {
            print("Failed to encode completion data: \(error.localizedDescription)")
            // If encoding fails, we should still queue it for retry
            OfflineQueueManager.shared.queueCompletion(completion)
        }
    }
}