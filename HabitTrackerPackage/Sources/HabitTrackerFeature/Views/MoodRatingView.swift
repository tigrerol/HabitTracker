import SwiftUI

/// View for rating mood after completing a routine
public struct MoodRatingView: View {
    @Environment(RoutineService.self) private var routineService
    @Environment(\.dismiss) private var dismiss
    
    let sessionId: UUID
    
    @State private var selectedMood: Mood?
    @State private var notes: String = ""
    
    public init(sessionId: UUID) {
        self.sessionId = sessionId
    }
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                headerView
                
                moodSelection
                
                notesSection
                
                Spacer()
                
                saveButton
            }
            .padding()
            .navigationTitle(String(localized: "MoodRatingView.NavigationTitle", bundle: .module))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "MoodRatingView.Skip", bundle: .module)) {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    private var headerView: some View {
        VStack(spacing: 12) {
            Text(String(localized: "MoodRatingView.Header.Emoji", bundle: .module))
                .font(.system(size: 60))
            
            Text(String(localized: "MoodRatingView.Header.Title", bundle: .module))
                .font(.headline)
                .multilineTextAlignment(.center)
            
            Text(String(localized: "MoodRatingView.Header.Subtitle", bundle: .module))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var moodSelection: some View {
        VStack(spacing: 16) {
            Text(String(localized: "MoodRatingView.Selection.Question", bundle: .module))
                .font(.subheadline)
                .fontWeight(.medium)
            
            HStack(spacing: 20) {
                ForEach(Mood.allCases, id: \.self) { mood in
                    Button {
                        selectedMood = mood
                    } label: {
                        VStack(spacing: 8) {
                            Text(mood.rawValue)
                                .font(.system(size: 40))
                                .scaleEffect(selectedMood == mood ? 1.2 : 1.0)
                                .animation(.bouncy, value: selectedMood)
                            
                            Text(mood.description)
                                .font(.caption)
                                .fontWeight(selectedMood == mood ? .semibold : .regular)
                                .foregroundStyle(selectedMood == mood ? .primary : .secondary)
                        }
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "MoodRatingView.Notes.Label", bundle: .module))
                .font(.subheadline)
                .fontWeight(.medium)
            
            TextField(String(localized: "MoodRatingView.Notes.Placeholder", bundle: .module), text: $notes, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...6)
        }
    }
    
    private var saveButton: some View {
        Button {
            if let selectedMood {
                routineService.addMoodRating(
                    selectedMood,
                    for: sessionId,
                    notes: notes.isEmpty ? nil : notes
                )
            }
            dismiss()
        } label: {
            Text(String(localized: "MoodRatingView.Save", bundle: .module))
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    selectedMood != nil ? .blue : .gray,
                    in: RoundedRectangle(cornerRadius: 12)
                )
        }
        .disabled(selectedMood == nil)
    }
}

#Preview {
    MoodRatingView(sessionId: UUID())
        .environment(RoutineService())
}