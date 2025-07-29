import SwiftUI

/// Main view for executing a morning routine
public struct RoutineExecutionView: View {
    @Environment(RoutineService.self) private var routineService
    @State private var sessionData: SessionDisplayData?
    @State private var showingCancelAlert = false
    
    public init() {}
    
    struct SessionDisplayData {
        let id: UUID
        let templateName: String
        let templateColor: String
        let isCompleted: Bool
        let currentHabit: Habit?
        let activeHabits: [Habit]
        let completions: [HabitCompletion]
        let progress: Double
        let durationString: String
        let completedCount: Int
        let totalCount: Int
        let currentHabitIndex: Int
        
        @MainActor
        static func from(_ session: RoutineSession) -> SessionDisplayData? {
            // Safely extract all data without triggering observation
            guard let templateName = session.template.name.isEmpty ? nil : session.template.name else { return nil }
            
            let activeHabits = session.activeHabits
            let completions = session.completions
            let currentHabitIndex = session.currentHabitIndex
            let currentHabit = currentHabitIndex >= 0 && currentHabitIndex < activeHabits.count ? activeHabits[currentHabitIndex] : nil
            let isCompleted = session.completedAt != nil
            
            
            // Safely calculate duration
            let duration = session.duration
            let durationString = duration.formattedDuration
            
            return SessionDisplayData(
                id: session.id,
                templateName: templateName,
                templateColor: session.template.color,
                isCompleted: isCompleted,
                currentHabit: currentHabit,
                activeHabits: activeHabits,
                completions: completions,
                progress: session.progress,
                durationString: durationString,
                completedCount: completions.filter { !$0.isSkipped }.count,
                totalCount: activeHabits.count,
                currentHabitIndex: currentHabitIndex
            )
        }
    }
    
    public var body: some View {
        NavigationStack {
            Group {
                if let data = sessionData {
                    if data.isCompleted {
                        completionViewFromData(data)
                    } else {
                        activeRoutineViewFromData(data)
                    }
                } else {
                    Text(String(localized: "RoutineExecutionView.NoActiveRoutine", bundle: .module))
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(sessionData?.templateName ?? String(localized: "RoutineExecutionView.NavigationTitle", bundle: .module))
            .toolbar {
                if sessionData != nil && !sessionData!.isCompleted {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Cancel") {
                            showingCancelAlert = true
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            .alert("Cancel Routine?", isPresented: $showingCancelAlert) {
                Button("Continue", role: .cancel) { }
                Button("Cancel Routine", role: .destructive) {
                    cancelRoutine()
                }
            } message: {
                Text("Your progress will be lost.")
            }
            .onReceive(NotificationCenter.default.publisher(for: .routineQueueDidChange)) { _ in
                // Force view refresh when routine queue changes (for conditional habits)
                if let session = routineService.currentSession {
                    sessionData = SessionDisplayData.from(session)
                }
            }
            .onChange(of: routineService.currentSession) { _, newSession in
                // Safely extract data when session changes
                if let session = newSession {
                    sessionData = SessionDisplayData.from(session)
                } else {
                    sessionData = nil
                }
            }
            .onAppear {
                // Initial data extraction
                if let session = routineService.currentSession {
                    sessionData = SessionDisplayData.from(session)
                }
            }
        }
    }
    
    
    
    
    
    
    
    @ViewBuilder
    private func completionViewFromData(_ data: SessionDisplayData) -> some View {
        RoutineCompletionView(data: data) {
            do {
                try routineService.completeCurrentSession()
                sessionData = nil // Clear the cached data
            } catch {
                // Handle error - could show an alert or log the error
                LoggingService.shared.error("Failed to complete routine session", category: .routine, metadata: ["error": error.localizedDescription])
            }
        }
    }
    
    @ViewBuilder
    private func activeRoutineViewFromData(_ data: SessionDisplayData) -> some View {
        VStack(spacing: 0) {
            // Progress header
            RoutineProgressHeaderView(data: data)
            
            // Habit overview
            HabitOverviewView(data: data) { index in
                routineService.currentSession?.goToHabit(at: index)
                refreshSessionData()
            }
            
            // Current habit with swipe gestures
            if let currentHabit = data.currentHabit {
                CurrentHabitView(
                    habit: currentHabit,
                    data: data,
                    onComplete: { habitId, duration, notes in
                        routineService.currentSession?.completeCurrentHabit(duration: duration, notes: notes)
                        refreshSessionData()
                    }
                )
                .gesture(
                    DragGesture()
                        .onEnded { value in
                            let threshold: CGFloat = AppConstants.Spacing.page + AppConstants.Spacing.large
                            
                            if value.translation.width > threshold {
                                // Swipe right - go to previous habit
                                routineService.currentSession?.goToPreviousHabit()
                                refreshSessionData()
                            } else if value.translation.width < -threshold {
                                // Swipe left - complete current habit
                                routineService.currentSession?.completeCurrentHabit()
                                refreshSessionData()
                            }
                        }
                )
            }
            
            // Navigation controls
            RoutineNavigationControlsView(data: data) {
                // Previous
                routineService.currentSession?.goToPreviousHabit()
                refreshSessionData()
            } onSkip: {
                // Skip
                routineService.currentSession?.skipCurrentHabit()
                refreshSessionData()
            }
        }
        .background(Color(.gray).opacity(0.05))
    }
    
    // MARK: - Helper Methods
    
    /// Refresh session data after any state change
    private func refreshSessionData() {
        if let session = routineService.currentSession {
            sessionData = SessionDisplayData.from(session)
        }
    }
    
    /// Cancel the current routine session
    private func cancelRoutine() {
        do {
            // This will cancel the current session and clean up any partial data
            try routineService.cancelCurrentSession()
            sessionData = nil // Clear the cached data
        } catch {
            // Handle error - could show an alert or log the error
            LoggingService.shared.error("Failed to cancel routine session", category: .routine, metadata: ["error": error.localizedDescription])
        }
    }
}

// Helper extension for time formatting
extension TimeInterval {
    var formattedDuration: String {
        // Defensive programming: ensure valid values
        guard self.isFinite && self >= 0 else { return "0:00" }
        
        let totalSeconds = Int(self)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        
        // Use string interpolation instead of format
        return "\(minutes):\(seconds < 10 ? "0" : "")\(seconds)"
    }
}

#Preview {
    RoutineExecutionView()
        .environment(RoutineService())
}