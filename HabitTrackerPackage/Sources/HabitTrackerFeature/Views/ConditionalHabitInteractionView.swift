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
        VStack(spacing: AppConstants.Spacing.extraLarge) {
            // Question
            VStack(spacing: AppConstants.Spacing.standard) {
                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Color(hex: habit.color) ?? .blue)
                
                Text(conditionalInfo.question)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(.top, AppConstants.Spacing.page)
            
            // Options
            VStack(spacing: AppConstants.Spacing.medium) {
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
                Text(String(localized: "ConditionalHabitInteractionView.Skip", bundle: .module))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .disabled(isProcessing)
            .padding(.bottom, AppConstants.Padding.extraLarge)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
    }
    
    private func selectOption(_ option: ConditionalOption) {
        guard !isProcessing else { return }
        
        isProcessing = true
        selectedOption = option
        
        // Add a small delay for visual feedback
        DispatchQueue.main.asyncAfter(deadline: .now() + AppConstants.AnimationDurations.standard) {
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
                                .fill(isSelected ? .white.opacity(0.2) : Color.gray.opacity(0.3))
                        )
                }
            }
            .padding(.horizontal, AppConstants.Padding.extraLarge)
            .padding(.vertical, AppConstants.Padding.large)
            .background(
                RoundedRectangle(cornerRadius: AppConstants.CornerRadius.medium)
                    .fill(isSelected ? color : Color.gray.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppConstants.CornerRadius.medium)
                    .strokeBorder(
                        isSelected ? color : Color.gray.opacity(0.4),
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
            .animation(.easeInOut(duration: AppConstants.AnimationDurations.accessibilityDelay), value: configuration.isPressed)
    }
}

// MARK: - Preview Provider
struct ConditionalHabitInteractionView_Previews: PreviewProvider {
    static var previews: some View {
        ConditionalHabitInteractionView(
            habit: Habit(
                name: String(localized: "ConditionalHabitInteractionView.Preview.PainAssessment", bundle: .module),
                type: .conditional(
                    ConditionalHabitInfo(
                        question: String(localized: "ConditionalHabitInteractionView.Preview.AnyPainToday", bundle: .module),
                        options: [
                            ConditionalOption(text: String(localized: "ConditionalHabitInteractionView.Preview.Shoulder", bundle: .module), habits: [
                                Habit(name: String(localized: "ConditionalHabitInteractionView.Preview.ShoulderStretches", bundle: .module), type: .timer(defaultDuration: 300)),
                                Habit(name: String(localized: "ConditionalHabitInteractionView.Preview.NerveGlides", bundle: .module), type: .checkbox)
                            ]),
                            ConditionalOption(text: String(localized: "ConditionalHabitInteractionView.Preview.Knee", bundle: .module), habits: [
                                Habit(name: String(localized: "ConditionalHabitInteractionView.Preview.KneeMobilization", bundle: .module), type: .timer(defaultDuration: 180))
                            ]),
                            ConditionalOption(text: String(localized: "ConditionalHabitInteractionView.Preview.Back", bundle: .module), habits: [
                                Habit(name: String(localized: "ConditionalHabitInteractionView.Preview.BackExtensions", bundle: .module), type: .checkbox)
                            ]),
                            ConditionalOption(text: String(localized: "ConditionalHabitInteractionView.Preview.None", bundle: .module), habits: [])
                        ]
                    )
                ),
                color: "#007AFF"
            ),
            conditionalInfo: ConditionalHabitInfo(
                question: String(localized: "ConditionalHabitInteractionView.Preview.AnyPainToday", bundle: .module),
                options: [
                    ConditionalOption(text: String(localized: "ConditionalHabitInteractionView.Preview.Shoulder", bundle: .module), habits: []),
                    ConditionalOption(text: String(localized: "ConditionalHabitInteractionView.Preview.Knee", bundle: .module), habits: []),
                    ConditionalOption(text: String(localized: "ConditionalHabitInteractionView.Preview.Back", bundle: .module), habits: []),
                    ConditionalOption(text: String(localized: "ConditionalHabitInteractionView.Preview.None", bundle: .module), habits: [])
                ]
            ),
            onOptionSelected: { _ in },
            onSkip: { }
        )
    }
}