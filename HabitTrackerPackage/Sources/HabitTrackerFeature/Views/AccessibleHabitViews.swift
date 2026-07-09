import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(ActivityKit)
import ActivityKit
#endif

/// Example enhanced habit views with comprehensive accessibility support
/// These demonstrate how to implement accessibility across different habit types

// MARK: - Accessible Checkbox Habit View

struct AccessibleCheckboxHabitView: View {
    let habit: Habit
    let onComplete: (UUID, TimeInterval?, String?) -> Void
    let isCompleted: Bool
    
    var body: some View {
        ModernCard(style: isCompleted ? .elevated : .standard) {
            VStack(spacing: 16) {
                // Habit Info Header
                HStack {
                    Image(systemName: habit.type.iconName)
                        .font(.title2)
                        .foregroundColor(habit.swiftUIColor)
                        .frame(minWidth: 32, minHeight: 32)
                        .background(
                            Circle()
                                .fill(habit.swiftUIColor.opacity(0.1))
                        )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(habit.name)
                            .customHeadline()
                            .lineLimit(2)
                        
                        Text(habit.type.description)
                            .customCaption()
                    }
                    
                    Spacer()
                }
                
                // Checkbox Button
                Button {
                    HapticManager.trigger(isCompleted ? .success : .medium)
                    onComplete(habit.id, nil, nil)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.title)
                            .foregroundStyle(isCompleted ? Theme.Colors.accentGreen : Theme.secondaryText)
                        
                        Text(isCompleted ?
                             String(localized: "HabitInteractionView.Checkbox.Completed", bundle: .module) :
                             String(localized: "HabitInteractionView.Checkbox.TapToComplete", bundle: .module))
                            .customSubheadline()
                            .foregroundColor(isCompleted ? Theme.Colors.accentGreen : Theme.text)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isCompleted ? Theme.Colors.accentGreen.opacity(0.1) : Color.gray.opacity(0.05))
                    )
                }
                .accessibilityButton(
                    identifier: AccessibilityConfiguration.Identifiers.completeHabitButton(habitId: habit.id),
                    label: AccessibilityConfiguration.Labels.checkboxHabit(
                        habitName: habit.name,
                        isCompleted: isCompleted
                    ),
                    hint: AccessibilityConfiguration.Hints.doubleTapToComplete,
                    traits: AccessibilityConfiguration.habitCardTraits
                )
                .disabled(isCompleted)
                .buttonStyle(ScaleButtonStyle())
                .sensoryFeedback(.selection, trigger: isCompleted)
            }
        }
    }
}

// MARK: - Accessible Counter Habit View

struct AccessibleCounterHabitView: View {
    let habit: Habit
    let items: [String]
    let onComplete: (UUID, TimeInterval?, String?) -> Void
    let isCompleted: Bool
    
    @State private var completedItems: Set<Int> = []
    
    var body: some View {
        VStack(spacing: 20) {
            // Progress summary
            Text(String(format: String(localized: "HabitInteractionView.Counter.CompletedItems", bundle: .module), 
                       completedItems.count, items.count))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Progress: \(completedItems.count) of \(items.count) items completed")
            
            // Items list
            LazyVStack(spacing: 8) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack {
                        Button {
                            toggleItem(index)
                        } label: {
                            HStack {
                                Image(systemName: completedItems.contains(index) ? 
                                      "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(completedItems.contains(index) ? .green : .secondary)
                                
                                Text(item)
                                    .strikethrough(completedItems.contains(index))
                                    .foregroundStyle(completedItems.contains(index) ? .secondary : .primary)
                                
                                Spacer()
                            }
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .accessibilityButton(
                            identifier: AccessibilityConfiguration.Identifiers.counterItem(index: index),
                            label: AccessibilityConfiguration.Labels.counterHabit(
                                habitName: habit.name,
                                itemName: item,
                                count: completedItems.contains(index) ? 1 : 0
                            ),
                            hint: completedItems.contains(index) ? 
                                "Double tap to mark as incomplete" :
                                "Double tap to mark as complete"
                        )
                    }
                }
            }
            
            // Complete button
            if completedItems.count == items.count && items.count > 0 {
                Button {
                    completeHabit()
                } label: {
                    Text(String(localized: "HabitInteractionView.Complete.Button", bundle: .module))
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 38)
                }
                .buttonStyle(.glassProminent)
                .tint(Color.green)
                .accessibilityButton(
                    identifier: AccessibilityConfiguration.Identifiers.completeHabitButton(habitId: habit.id),
                    label: AccessibilityConfiguration.Labels.completeHabitButton(habitName: habit.name),
                    hint: AccessibilityConfiguration.Hints.doubleTapToComplete
                )
            }
        }
        .padding()
    }
    
    private func toggleItem(_ index: Int) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if completedItems.contains(index) {
                completedItems.remove(index)
            } else {
                completedItems.insert(index)
            }
        }
        
        // Provide haptic feedback
        #if canImport(UIKit)
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        #endif
        
        // Announce the change
        let itemName = items[index]
        let isCompleted = completedItems.contains(index)
        #if canImport(UIKit)
        UIAccessibility.post(
            notification: .announcement,
            argument: "\(itemName) marked as \(isCompleted ? "complete" : "incomplete")"
        )
        #endif
    }
    
    private func completeHabit() {
        let completedItemNames = completedItems.compactMap { index in
            index < items.count ? items[index] : nil
        }
        
        // Announce completion
        #if canImport(UIKit)
        UIAccessibility.post(
            notification: .announcement,
            argument: AccessibilityConfiguration.Announcements.habitCompleted(habitName: habit.name)
        )
        #endif
        
        onComplete(habit.id, nil, "Completed items: \(completedItemNames.joined(separator: ", "))")
    }
}
