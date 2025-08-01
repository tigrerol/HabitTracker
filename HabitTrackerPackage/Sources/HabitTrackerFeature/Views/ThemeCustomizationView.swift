import SwiftUI

// MARK: - Theme Customization View

public struct ThemeCustomizationView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedColor: Color = ThemeManager.shared.currentAccentColor
    @State private var showingPreview = false
    @State private var interactionState = InteractionState()
    @Namespace private var colorTransition
    
    private let themeManager = ThemeManager.shared
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Preview Section
                    previewSection
                    
                    // Color Grid
                    colorSelectionGrid
                    
                    // Custom Color Picker (iOS 16+)
                    customColorPicker
                    
                    // Apply Button
                    applyButton
                }
                .padding()
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Customize Theme")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Preview Section
    
    private var previewSection: some View {
        ModernCard(style: .elevated) {
            VStack(spacing: 20) {
                Text("Preview")
                    .customHeadline()
                
                // Sample UI Elements
                VStack(spacing: 16) {
                    // Habit Card Preview
                    HStack {
                        Circle()
                            .fill(selectedColor.opacity(0.2))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Image(systemName: "timer")
                                    .foregroundColor(selectedColor)
                            )
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Morning Meditation")
                                .customSubheadline()
                            Text("5 minutes • Timer")
                                .customCaption()
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Circle()
                            .stroke(selectedColor, lineWidth: 2)
                            .frame(width: 24, height: 24)
                    }
                    .padding()
                    .background(Theme.cardBackground)
                    .cornerRadius(12)
                    
                    // Buttons Preview
                    HStack(spacing: 12) {
                        Button {
                            HapticManager.trigger(.light)
                        } label: {
                            Text("Primary")
                                .customSubheadline()
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(selectedColor)
                                .cornerRadius(20)
                        }
                        
                        Button {
                            HapticManager.trigger(.light)
                        } label: {
                            Text("Secondary")
                                .customSubheadline()
                                .foregroundColor(selectedColor)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(
                                    Capsule()
                                        .stroke(selectedColor, lineWidth: 2)
                                )
                        }
                    }
                    
                    // Progress Bar Preview
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Progress")
                            .customCaption()
                            .foregroundColor(.secondary)
                        
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 8)
                                
                                Capsule()
                                    .fill(selectedColor)
                                    .frame(width: geometry.size.width * 0.65, height: 8)
                            }
                        }
                        .frame(height: 8)
                    }
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selectedColor)
            }
        }
    }
    
    // MARK: - Color Selection Grid
    
    private var colorSelectionGrid: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Choose Accent Color")
                    .customHeadline()
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    ForEach(themeManager.availableColors, id: \.name) { item in
                        ColorSelectionButton(
                            color: item.color,
                            isSelected: selectedColor.description == item.color.description,
                            namespace: colorTransition,
                            interactionState: interactionState,
                            action: {
                                withAnimation(AnimationPresets.smoothSpring) {
                                    selectedColor = item.color
                                    HapticManager.trigger(.selection)
                                }
                            }
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Custom Color Picker
    
    private var customColorPicker: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Custom Color")
                    .customHeadline()
                
                ColorPicker("Pick any color", selection: $selectedColor)
                    .labelsHidden()
                    .frame(height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.1))
                    )
            }
        }
    }
    
    // MARK: - Apply Button
    
    private var applyButton: some View {
        PrimaryButton("Apply Theme") {
            applyTheme()
        }
        .padding(.top)
    }
    
    // MARK: - Actions
    
    private func applyTheme() {
        themeManager.updateAccentColor(selectedColor)
        HapticManager.trigger(.success)
        dismiss()
    }
}

// MARK: - Color Selection Button

struct ColorSelectionButton: View {
    let color: Color
    let isSelected: Bool
    let namespace: Namespace.ID
    let interactionState: InteractionState
    let action: () -> Void
    
    private var colorId: String {
        color.description
    }
    
    private var isPressed: Bool {
        interactionState.isPressed(colorId)
    }
    
    var body: some View {
        Button(action: action) {
            Circle()
                .fill(color)
                .frame(width: 50, height: 50)
                .matchedGeometry(
                    id: isSelected ? GeometryEffectID.selectedColor : GeometryEffectID.colorPicker,
                    in: namespace,
                    isSource: isSelected
                )
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 3)
                        .opacity(isSelected ? 1 : 0)
                        .scaleEffect(isSelected ? 1.0 : 0.8)
                )
                .overlay(
                    Circle()
                        .stroke(color.opacity(0.3), lineWidth: isSelected ? 4 : 0)
                        .frame(width: 58, height: 58)
                        .scaleEffect(isSelected ? 1.0 : 0.9)
                )
                .shadow(
                    color: color.opacity(isPressed ? 0.5 : 0.3), 
                    radius: isSelected ? 12 : (isPressed ? 6 : 4), 
                    x: 0, 
                    y: isPressed ? 1 : 2
                )
                .scaleEffect(isSelected ? 1.1 : (isPressed ? 0.95 : 1.0))
                .animation(AnimationPresets.quickSpring, value: isSelected)
                .animation(AnimationPresets.quickSpring, value: isPressed)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    interactionState.setPressed(colorId, isPressed: true)
                }
                .onEnded { _ in
                    interactionState.setPressed(colorId, isPressed: false)
                }
        )
    }
}

// MARK: - Preview

#Preview {
    ThemeCustomizationView()
}