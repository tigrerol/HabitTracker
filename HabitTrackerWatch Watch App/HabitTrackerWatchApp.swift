//
//  HabitTrackerWatchApp.swift
//  HabitTrackerWatch Watch App
//
//  Created by Roland Lechner on 27.07.25.
//

import SwiftUI
import SwiftData

@main
struct HabitTrackerWatch_Watch_AppApp: App {
    let modelContainer: ModelContainer
    
    init() {
        do {
            modelContainer = try ModelContainer(for: PersistedRoutineTemplate.self)
        } catch {
            fatalError("Failed to create model container: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            RoutineListView()
                .modelContainer(modelContainer)
                .onAppear {
                    // Set up managers with model context
                    let context = modelContainer.mainContext
                    WatchConnectivityManager.shared.setModelContext(context)
                    WatchConnectivityManager.shared.loadRoutinesFromStorage()
                    
                    OfflineQueueManager.shared.setModelContext(context)
                }
        }
    }
}
