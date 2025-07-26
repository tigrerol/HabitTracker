import SwiftUI

/// Inline mood rating component for the completion screen
struct InlineMoodRatingView: View {
    @Environment(RoutineService.self) private var routineService
    
    let sessionId: UUID
    
    @State private var selectedMood: Mood?
    @State private var hasRated = false
    
    var body: some View {
        VStack(spacing: 16) {
            Text(String(localized: "InlineMoodRatingView.Question", bundle: .module))
                .font(.headline)
                .fontWeight(.medium)
            
            HStack(spacing: 16) {
                ForEach(Mood.allCases, id: \.self) { mood in
                    Button {
                        withAnimation(.bouncy) {
                            selectedMood = mood
                            rateMood(mood)
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Text(mood.rawValue)
                                .font(.system(size: selectedMood == mood ? 44 : 36))
                                .scaleEffect(selectedMood == mood ? 1.1 : 1.0)
                            
                            if selectedMood == mood {
                                Text(mood.description)
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.primary)
                            }
                        }
                        .padding(.vertical, 4)
                        .background {
                            if selectedMood == mood {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(.regularMaterial)
                                    .stroke(.blue, lineWidth: 2)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(hasRated && selectedMood != mood)
                }
            }
            
            if hasRated {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(String(localized: "InlineMoodRatingView.ThankYou", bundle: .module))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .transition(.opacity.combined(with: .scale))
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    private func rateMood(_ mood: Mood) {
        guard !hasRated else { return }
        
        selectedMood = mood
        hasRated = true
        
        routineService.addMoodRating(mood, for: sessionId)
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
}

#Preview {
    InlineMoodRatingView(sessionId: UUID())
        .environment(RoutineService())
        .padding()
}