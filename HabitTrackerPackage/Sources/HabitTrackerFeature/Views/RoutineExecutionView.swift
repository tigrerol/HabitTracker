import SwiftUI

/// Main view for executing a morning routine
public struct RoutineExecutionView: View {
    @Environment(RoutineService.self) private var routineService
    @State private var sessionData: SessionDisplayData?
    
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
            .navigationBarTitleDisplayMode(.inline)
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
        VStack(spacing: AppConstants.Spacing.extraLarge) {
            Spacer()
            
            // Celebration
            VStack(spacing: AppConstants.Spacing.large) {
                Text("🎉")
                    .font(.system(size: AppConstants.FontSizes.largeIcon))
                
                Text(String(localized: "RoutineExecutionView.RoutineComplete", bundle: .module))
                    .font(.title)
                    .fontWeight(.bold)
                
                // Use simple string interpolation to avoid String.format issues
                Text("You completed \(data.completedCount) of \(data.totalCount) habits in \(data.durationString)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Inline Mood Rating
            InlineMoodRatingView(sessionId: data.id)
            
            Spacer()
            
            // Quick Finish
            Button {
                routineService.completeCurrentSession()
                sessionData = nil // Clear the cached data
            } label: {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text(String(localized: "RoutineExecutionView.AllDone", bundle: .module))
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(hex: data.templateColor) ?? .blue, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding()
    }
    
    @ViewBuilder
    private func activeRoutineViewFromData(_ data: SessionDisplayData) -> some View {
        VStack(spacing: 0) {
            // Progress header
            progressHeaderFromData(data)
            
            // Habit overview
            habitOverviewFromData(data)
            
            // Current habit with swipe gestures
            if let currentHabit = data.currentHabit {
                currentHabitViewFromData(currentHabit, data: data)
                    .accessibilityHabitInteraction(
                        habit: currentHabit,
                        customHint: AccessibilityConfiguration.Hints.swipeToNavigate
                    )
                    .gesture(
                        DragGesture()
                            .onEnded { value in
                                let threshold: CGFloat = AppConstants.Spacing.page + AppConstants.Spacing.large
                                
                                if value.translation.width > threshold {
                                    // Swipe right - go to previous habit
                                    routineService.currentSession?.goToPreviousHabit()
                                    // Refresh the cached data
                                    if let session = routineService.currentSession {
                                        sessionData = SessionDisplayData.from(session)
                                    }
                                } else if value.translation.width < -threshold {
                                    // Swipe left - complete current habit
                                    routineService.currentSession?.completeCurrentHabit()
                                    // Refresh the cached data
                                    if let session = routineService.currentSession {
                                        sessionData = SessionDisplayData.from(session)
                                    }
                                }
                            }
                    )
            }
            
            // Navigation controls
            navigationControlsFromData(data)
        }
        .background(Color(.systemGroupedBackground))
    }
    
    @ViewBuilder
    private func progressHeaderFromData(_ data: SessionDisplayData) -> some View {
        VStack(spacing: 12) {
            // Progress bar
            ProgressView(value: data.progress)
                .tint(Color(hex: data.templateColor) ?? .blue)
                .scaleEffect(y: 2)
                .accessibilityProgress(
                    identifier: AccessibilityConfiguration.Identifiers.progressBar,
                    label: AccessibilityConfiguration.Labels.progressBar(
                        completed: data.completedCount,
                        total: data.totalCount
                    ),
                    value: data.progress
                )
            
            // Progress text
            HStack {
                Text(String(format: String(localized: "RoutineExecutionView.CompletedOfTotal", bundle: .module), data.completedCount, data.totalCount))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier(AccessibilityConfiguration.Identifiers.progressText)
                    .accessibilityHidden(true) // Hidden since progress bar provides the same info
                
                Spacer()
                
                Text(data.durationString)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .accessibilityIdentifier(AccessibilityConfiguration.Identifiers.durationText)
                    .accessibilityLabel("Duration: \(data.durationString)")
                    .accessibilityAddTraits(.updatesFrequently)
            }
        }
        .padding()
        .background(.regularMaterial)
    }
    
    @ViewBuilder
    private func currentHabitViewFromData(_ habit: Habit, data: SessionDisplayData) -> some View {
        VStack(spacing: AppConstants.Spacing.extraLarge) {
            // Habit info
            VStack(spacing: 8) {
                Image(systemName: habit.type.iconName)
                    .font(.system(size: AppConstants.Spacing.page))
                    .foregroundStyle(habit.swiftUIColor)
                
                Text(habit.name)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                
                Text(habit.type.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            // Habit-specific interaction
            HabitInteractionView(habit: habit, onComplete: { habitId, duration, notes in
                routineService.currentSession?.completeCurrentHabit(duration: duration, notes: notes)
                // Refresh the cached data after completion
                if let session = routineService.currentSession {
                    sessionData = SessionDisplayData.from(session)
                }
            }, isCompleted: data.completions.contains(where: { $0.habitId == habit.id }))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    @ViewBuilder
    private func habitOverviewFromData(_ data: SessionDisplayData) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Array(data.activeHabits.enumerated()), id: \.element.id) { index, habit in
                    VStack(spacing: 4) {
                        Circle()
                            .fill(habitStatusColorFromData(for: habit, data: data))
                            .frame(width: 12, height: 12)
                        
                        Text(habit.name)
                            .font(.caption2)
                            .lineLimit(1)
                    }
                    .id(habit.id) // Force unique view identity for entire VStack
                    .opacity(index == data.currentHabitIndex ? 1 : 0.6)
                    .onTapGesture {
                        routineService.currentSession?.goToHabit(at: index)
                        // Refresh the cached data
                        if let session = routineService.currentSession {
                            sessionData = SessionDisplayData.from(session)
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding()
        .background(.regularMaterial)
    }
    
    @ViewBuilder
    private func navigationControlsFromData(_ data: SessionDisplayData) -> some View {
        HStack(spacing: AppConstants.Spacing.large) {
            // Previous habit
            Button {
                routineService.currentSession?.goToPreviousHabit()
                // Refresh the cached data
                if let session = routineService.currentSession {
                    sessionData = SessionDisplayData.from(session)
                }
            } label: {
                HStack {
                    Image(systemName: "chevron.left")
                    Text(String(localized: "RoutineExecutionView.Previous", bundle: .module))
                }
                .font(.caption)
                .foregroundStyle(data.currentHabitIndex > 0 ? .blue : .gray)
                .padding(.vertical, 8)
                .background(.regularMaterial, in: Capsule())
            }
            .disabled(data.currentHabitIndex <= 0)
            .buttonStyle(.plain)
            
            Spacer()
            
            // Skip current habit
            Button {
                routineService.currentSession?.skipCurrentHabit()
                // Refresh the cached data
                if let session = routineService.currentSession {
                    sessionData = SessionDisplayData.from(session)
                }
            } label: {
                HStack {
                    Image(systemName: "forward.fill")
                    Text(String(localized: "RoutineExecutionView.Skip", bundle: .module))
                }
                .font(.caption)
                .foregroundStyle(.orange)
                .padding(.vertical, 8)
                .background(.regularMaterial, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(.regularMaterial)
    }
    
    private func habitStatusColorFromData(for habit: Habit, data: SessionDisplayData) -> Color {
        let isCompleted = data.completions.contains(where: { $0.habitId == habit.id })
        let isCurrent = data.currentHabit?.id == habit.id
        
        if isCompleted {
            return .green
        } else if isCurrent {
            return habit.swiftUIColor
        } else {
            return .gray.opacity(0.3)
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