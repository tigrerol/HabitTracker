import SwiftUI

// MARK: - Theme Customization View

public struct ThemeCustomizationView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedColor: Color = ThemeManager.shared.currentAccentColor
    @State private var showingPreview = false
    
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
                            action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
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
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Circle()
                .fill(color)
                .frame(width: 50, height: 50)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 3)
                        .opacity(isSelected ? 1 : 0)
                )
                .overlay(
                    Circle()
                        .stroke(color.opacity(0.3), lineWidth: isSelected ? 4 : 0)
                        .frame(width: 58, height: 58)
                )
                .shadow(color: color.opacity(0.3), radius: isSelected ? 8 : 4, x: 0, y: 2)
                .scaleEffect(isSelected ? 1.1 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
        }
    }
}

// MARK: - Preview

#Preview {
    ThemeCustomizationView()
}