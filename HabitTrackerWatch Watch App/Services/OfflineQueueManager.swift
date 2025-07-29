import Foundation
import SwiftData
import SwiftUI

@Observable
@MainActor
final class OfflineQueueManager {
    static let shared = OfflineQueueManager()
    
    private var modelContext: ModelContext?
    private var queuedCompletions: [RoutineSession] = []
    
    private init() {}
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        loadQueuedCompletions()
    }
    
    // MARK: - Queue Management
    
    func queueCompletion(_ session: RoutineSession) {
        // For the watch app, we'll keep a simple in-memory queue
        // Since sessions are not persisted to SwiftData on watch
        var queuedSession = session
        queuedSession.isCompleted = true
        queuedCompletions.append(queuedSession)
        
        print("Queued routine completion: \(session.routineName)")
        
        // Try to send immediately if connected
        tryProcessQueue()
    }
    
    func tryProcessQueue() {
        guard !queuedCompletions.isEmpty else { return }
        
        let connectivityManager = WatchConnectivityManager.shared
        
        // Only process if we have an active connection
        guard connectivityManager.isConnected else {
            print("iPhone not reachable. Keeping \(queuedCompletions.count) completions in queue.")
            return
        }
        
        print("Processing \(queuedCompletions.count) queued completions...")
        
        // Send all queued completions
        for completion in queuedCompletions {
            connectivityManager.sendCompletionToiOS(completion)
        }
        
        // Clear the queue after successful sending
        queuedCompletions.removeAll()
        print("Successfully processed all queued completions.")
    }
    
    private func loadQueuedCompletions() {
        // For the watch app, we start with an empty queue
        // Sessions are not persisted to SwiftData on watch - they're only sent to iOS
        queuedCompletions = []
        print("Loaded \(queuedCompletions.count) completed sessions.")
    }
    
    // MARK: - Connectivity Events
    
    func onConnectivityChanged(isConnected: Bool) {
        if isConnected {
            print("iPhone connection restored. Processing queue...")
            tryProcessQueue()
        } else {
            print("iPhone connection lost. Will queue completions for later.")
        }
    }
    
    // MARK: - Queue Status
    
    var hasQueuedItems: Bool {
        !queuedCompletions.isEmpty
    }
    
    var queuedItemsCount: Int {
        queuedCompletions.count
    }
    
    // MARK: - Manual Sync
    
    func forceSyncIfPossible() {
        let connectivityManager = WatchConnectivityManager.shared
        
        if connectivityManager.isConnected {
            tryProcessQueue()
        } else {
            print("Cannot force sync: iPhone not reachable.")
        }
    }
    
    // MARK: - Clear Processed Items
    
    func clearProcessedCompletions() {
        // Clear the in-memory queue
        queuedCompletions.removeAll()
        print("Cleared processed completions from queue.")
    }
}

// MARK: - Queue Status View Model

@Observable
@MainActor
final class QueueStatusViewModel {
    private let queueManager = OfflineQueueManager.shared
    private let connectivityManager = WatchConnectivityManager.shared
    
    private var showSyncedMessage = false
    private var hideTask: Task<Void, Never>?
    
    init() {
        // Listen for sync completion notifications
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("WatchSyncCompleted"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.onSyncCompleted()
            }
        }
    }
    
    var isConnected: Bool {
        connectivityManager.isConnected
    }
    
    var hasQueuedItems: Bool {
        queueManager.hasQueuedItems
    }
    
    var queuedItemsCount: Int {
        queueManager.queuedItemsCount
    }
    
    var statusText: String {
        if isConnected {
            if hasQueuedItems {
                return "Syncing \(queuedItemsCount) items..."
            } else if showSyncedMessage {
                return "Synced"
            } else {
                return "" // Hidden after 5 seconds or never shown yet
            }
        } else {
            if hasQueuedItems {
                return "\(queuedItemsCount) items queued"
            } else {
                return "Offline"
            }
        }
    }
    
    var statusColor: Color {
        if isConnected {
            return hasQueuedItems ? .orange : .green
        } else {
            return hasQueuedItems ? .yellow : .gray
        }
    }
    
    func forceSyncIfPossible() {
        queueManager.forceSyncIfPossible()
        onSyncCompleted()
    }
    
    func onSyncCompleted() {
        // Cancel any existing hide task
        hideTask?.cancel()
        
        // Show the message immediately
        showSyncedMessage = true
        
        // Start new task to hide after 5 seconds
        hideTask = Task {
            try? await Task.sleep(for: .seconds(5))
            if !Task.isCancelled {
                await MainActor.run {
                    showSyncedMessage = false
                }
            }
        }
    }
}

// MARK: - Queue Status View

struct QueueStatusView: View {
    @State private var viewModel = QueueStatusViewModel()
    
    var body: some View {
        Group {
            if !viewModel.statusText.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: viewModel.isConnected ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(viewModel.statusColor)
                        .font(.caption)
                    
                    Text(viewModel.statusText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if viewModel.hasQueuedItems && viewModel.isConnected {
                        Button("Sync") {
                            viewModel.forceSyncIfPossible()
                        }
                        .font(.caption)
                        .buttonStyle(.borderless)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
                .transition(.opacity.combined(with: .scale))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.statusText.isEmpty)
        .onChange(of: viewModel.hasQueuedItems) { oldValue, newValue in
            // Detect when we transition from having items to no items while connected
            if oldValue && !newValue && viewModel.isConnected {
                print("Sync completed - triggering auto-hide message")
                viewModel.onSyncCompleted()
            }
        }
    }
}