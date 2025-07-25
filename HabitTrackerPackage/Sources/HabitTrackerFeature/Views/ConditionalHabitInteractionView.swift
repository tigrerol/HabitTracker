import SwiftUI

/// View for interacting with a conditional habit during routine execution
public struct ConditionalHabitInteractionView: View {
    let habit: Habit
    let conditionalInfo: ConditionalHabitInfo
    let onOptionSelected: (ConditionalOption) -> Void
    let onSkip: () -> Void
    
    @State private var selectedOption: ConditionalOption?
    @State private var isProcessing = false
    
    public init(
        habit: Habit,
        conditionalInfo: ConditionalHabitInfo,
        onOptionSelected: @escaping (ConditionalOption) -> Void,
        onSkip: @escaping () -> Void
    ) {
        self.habit = habit
        self.conditionalInfo = conditionalInfo
        self.onOptionSelected = onOptionSelected
        self.onSkip = onSkip
    }
    
    public var body: some View {
        VStack(spacing: 24) {
            // Question
            VStack(spacing: 8) {
                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Color(hex: habit.color) ?? .blue)
                
                Text(conditionalInfo.question)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(.top, 40)
            
            // Options
            VStack(spacing: 12) {
                ForEach(conditionalInfo.options) { option in
                    OptionButton(
                        option: option,
                        isSelected: selectedOption?.id == option.id,
                        color: Color(hex: habit.color) ?? .blue
                    ) {
                        selectOption(option)
                    }
                    .disabled(isProcessing)
                }
            }
            .padding(.horizontal)
            
            Spacer()
            
            // Skip button
            Button {
                onSkip()
            } label: {
                Text("Skip")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .disabled(isProcessing)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
    
    private func selectOption(_ option: ConditionalOption) {
        guard !isProcessing else { return }
        
        isProcessing = true
        selectedOption = option
        
        // Add a small delay for visual feedback
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onOptionSelected(option)
        }
    }
}

private struct OptionButton: View {
    let option: ConditionalOption
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(option.text)
                    .font(.headline)
                    .foregroundStyle(isSelected ? .white : .primary)
                
                Spacer()
                
                if !option.habits.isEmpty {
                    Text("\(option.habits.count)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(isSelected ? .white.opacity(0.2) : Color(.systemGray5))
                        )
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? color : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        isSelected ? color : Color(.systemGray4),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(OptionButtonStyle())
    }
}

private struct OptionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Preview Provider
struct ConditionalHabitInteractionView_Previews: PreviewProvider {
    static var previews: some View {
        ConditionalHabitInteractionView(
            habit: Habit(
                name: "Pain Assessment",
                type: .conditional(
                    ConditionalHabitInfo(
                        question: "Any pain today?",
                        options: [
                            ConditionalOption(text: "Shoulder", habits: [
                                Habit(name: "Shoulder Stretches", type: .timer(defaultDuration: 300)),
                                Habit(name: "Nerve Glides", type: .checkbox)
                            ]),
                            ConditionalOption(text: "Knee", habits: [
                                Habit(name: "Knee Mobilization", type: .timer(defaultDuration: 180))
                            ]),
                            ConditionalOption(text: "Back", habits: [
                                Habit(name: "Back Extensions", type: .checkbox)
                            ]),
                            ConditionalOption(text: "None", habits: [])
                        ]
                    )
                ),
                color: "#007AFF"
            ),
            conditionalInfo: ConditionalHabitInfo(
                question: "Any pain today?",
                options: [
                    ConditionalOption(text: "Shoulder", habits: []),
                    ConditionalOption(text: "Knee", habits: []),
                    ConditionalOption(text: "Back", habits: []),
                    ConditionalOption(text: "None", habits: [])
                ]
            ),
            onOptionSelected: { _ in },
            onSkip: { }
        )
    }
}