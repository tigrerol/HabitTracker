import SwiftUI

// MARK: - Appearance View

/// Simple appearance settings: accent color + light/dark mode. Changes apply instantly.
public struct ThemeCustomizationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager

    public init() {}

    private let columns = [GridItem(.adaptive(minimum: 76), spacing: 16)]

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    // Appearance mode
                    VStack(alignment: .leading, spacing: 10) {
                        sectionLabel("Mode")

                        Picker("Appearance", selection: Binding(
                            get: { themeManager.appearanceMode },
                            set: { mode in
                                themeManager.updateAppearanceMode(mode)
                                HapticManager.trigger(.selection)
                            }
                        )) {
                            ForEach(AppearanceMode.allCases, id: \.rawValue) { mode in
                                Label(mode.displayName, systemImage: mode.icon)
                                    .tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    // Accent color
                    VStack(alignment: .leading, spacing: 10) {
                        sectionLabel("Accent Color")

                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(AccentPreset.all) { preset in
                                accentSwatch(preset)
                            }
                        }
                    }
                }
                .padding(20)
            }
            .appBackground()
            .navigationTitle("Appearance")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(.caption, design: .rounded, weight: .semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .tracking(0.5)
    }

    private func accentSwatch(_ preset: AccentPreset) -> some View {
        let isSelected = preset.hex.lowercased() == themeManager.accentHex.lowercased()

        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                themeManager.updateAccentColor(hex: preset.hex)
            }
            HapticManager.trigger(.selection)
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [preset.color, preset.color.opacity(0.75)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)

                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .overlay(
                    Circle()
                        .stroke(isSelected ? preset.color.opacity(0.5) : Theme.hairline, lineWidth: isSelected ? 3 : 1)
                        .padding(-4)
                )

                Text(preset.name)
                    .font(.system(.caption2, design: .rounded, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel("\(preset.name) accent color\(isSelected ? ", selected" : "")")
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Preview

#Preview {
    ThemeCustomizationView()
        .withDynamicTheme()
}
