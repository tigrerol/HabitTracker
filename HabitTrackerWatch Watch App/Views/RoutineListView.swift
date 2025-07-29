import SwiftUI
import SwiftData

@MainActor
struct RoutineListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var storedRoutines: [PersistedRoutineTemplate]
    @State private var connectivityManager = WatchConnectivityManager.shared
    
    var body: some View {
        NavigationStack {
            Group {
                if connectivityManager.routines.isEmpty && storedRoutines.isEmpty {
                    EmptyStateView()
                } else {
                    List {
                        ForEach(displayRoutines) { routine in
                            NavigationLink(destination: RoutineExecutionView(routine: routine)) {
                                RoutineRowView(routine: routine)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Routines")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                QueueStatusView()
                    .padding(.bottom, 8)
            }
        }
        .onAppear {
            connectivityManager.setModelContext(modelContext)
            connectivityManager.loadRoutinesFromStorage()
        }
    }
    
    private var displayRoutines: [RoutineTemplate] {
        // Prefer routines from connectivity manager (most up-to-date)
        if !connectivityManager.routines.isEmpty {
            return connectivityManager.routines
        }
        return storedRoutines.map { $0.toDomainModel() }
    }
}

struct RoutineRowView: View {
    let routine: RoutineTemplate
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Circle()
                    .fill(routine.swiftUIColor)
                    .frame(width: 12, height: 12)
                
                Text(routine.name)
                    .font(.headline)
                    .lineLimit(1)
                
                Spacer()
                
                Text(routine.formattedDuration)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if let description = routine.description, !description.isEmpty {
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            HStack {
                Image(systemName: "list.bullet")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("\(routine.activeHabitsCount) habits")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if routine.isDefault {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundColor(.yellow)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

struct EmptyStateView: View {
    @State private var connectivityManager = WatchConnectivityManager.shared
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "list.clipboard")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text("No Routines")
                .font(.headline)
            
            Text("Create routines on your iPhone and they'll appear here.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            HStack {
                Image(systemName: connectivityManager.isConnected ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundColor(connectivityManager.isConnected ? .green : .orange)
                
                Text(connectivityManager.isConnected ? "Connected to iPhone" : "Disconnected from iPhone")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 8)
        }
        .padding()
    }
}

#if DEBUG
struct RoutineListView_Previews: PreviewProvider {
    static var previews: some View {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: PersistedRoutineTemplate.self, configurations: config)
        
        // Add sample data
        let sampleRoutine = RoutineTemplate(
            name: "Morning Routine",
            description: "My daily morning habits",
            habits: [
                Habit(name: "Drink Water", type: .checkbox),
                Habit(name: "Meditation", type: .timer(defaultDuration: 600))
            ]
        )
        let persistedSample = PersistedRoutineTemplate(from: sampleRoutine)
        container.mainContext.insert(persistedSample)
        
        return RoutineListView()
            .modelContainer(container)
    }
}
#endif