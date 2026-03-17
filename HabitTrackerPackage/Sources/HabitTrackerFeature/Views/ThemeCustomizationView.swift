import SwiftUI

// MARK: - Theme Selection View

public struct ThemeCustomizationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager
    @State private var selectedTheme: AppTheme?
    @State private var appearScale = false

    public init() {}

    private var effectiveTheme: AppTheme {
        selectedTheme ?? themeManager.currentTheme
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 32) {
                        // Header description
                        VStack(spacing: 6) {
                            Text("Choose a look that fits your moment.")
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 8)

                        // Theme cards
                        VStack(spacing: 16) {
                            ForEach(themeManager.availableThemes, id: \.rawValue) { theme in
                                ThemePreviewCard(
                                    theme: theme,
                                    isSelected: effectiveTheme == theme
                                ) {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                        selectedTheme = theme
                                        HapticManager.trigger(.selection)
                                    }
                                }
                                .scaleEffect(appearScale ? 1.0 : 0.96)
                                .opacity(appearScale ? 1.0 : 0)
                                .animation(
                                    .spring(response: 0.5, dampingFraction: 0.8)
                                    .delay(theme == .sunstone ? 0.05 : 0.12),
                                    value: appearScale
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }

                // Apply button pinned at bottom
                VStack(spacing: 0) {
                    Divider()
                    Button {
                        themeManager.updateTheme(effectiveTheme)
                        HapticManager.trigger(.success)
                        dismiss()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.headline)
                            Text("Apply \(effectiveTheme.displayName)")
                                .font(.system(.headline, design: .rounded, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            effectiveTheme.accentColor,
                                            effectiveTheme.accentColor.opacity(0.8)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                    }
                    .accessibilityHint("Changes the app appearance and closes this screen")
                    .buttonStyle(ScaleButtonStyle())
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
                .background(.regularMaterial)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Theme")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(.secondary)
                }
            }
            .onAppear {
                withAnimation { appearScale = true }
            }
        }
    }
}

// MARK: - Theme Preview Card

private struct ThemePreviewCard: View {
    let theme: AppTheme
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {

                // Mini app preview
                themePreview
                    .frame(height: 200)
                    .clipped()

                // Label row
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(theme.displayName)
                            .font(.system(.headline, design: .rounded, weight: .bold))
                            .foregroundStyle(.primary)

                        Text(theme.tagline)
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    HStack(spacing: 8) {
                        // Mode badge
                        Text(theme.modeLabel)
                            .font(.system(.caption2, design: .rounded, weight: .semibold))
                            .foregroundStyle(theme.accentColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(theme.accentColor.opacity(0.12))
                            )

                        // Selection indicator
                        ZStack {
                            Circle()
                                .stroke(
                                    isSelected ? theme.accentColor : Color.primary.opacity(0.2),
                                    lineWidth: isSelected ? 2 : 1.5
                                )
                                .frame(width: 24, height: 24)

                            if isSelected {
                                Circle()
                                    .fill(theme.accentColor)
                                    .frame(width: 14, height: 14)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Theme.cardBackground)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(
                        isSelected ? theme.accentColor : Color.primary.opacity(0.08),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .shadow(
                color: isSelected ? theme.accentColor.opacity(0.15) : Color.black.opacity(0.06),
                radius: isSelected ? 16 : 8,
                x: 0,
                y: isSelected ? 6 : 3
            )
        }
        .accessibilityLabel("\(theme.displayName) theme, \(theme.modeLabel), \(theme.tagline)\(isSelected ? ", currently selected" : "")")
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - Mini App Preview

    @ViewBuilder
    private var themePreview: some View {
        ZStack {
            // Background
            theme.previewBackground

            VStack(spacing: 10) {
                // Progress header simulation
                previewProgressBar

                // Current habit simulation
                previewHabitCard

                // Nav controls simulation
                previewNavControls
            }
            .padding(14)
        }
    }

    private var previewProgressBar: some View {
        VStack(spacing: 6) {
            // Progress track
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(theme.previewTextPrimary.opacity(0.08))
                    .frame(height: 4)

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [theme.accentColor, theme.accentColor.opacity(0.7)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 120, height: 4)
            }

            HStack {
                Text("3 of 5")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(theme.previewTextSecondary)
                Spacer()
                HStack(spacing: 3) {
                    Image(systemName: "timer")
                        .font(.system(size: 8))
                        .foregroundStyle(theme.previewTextSecondary)
                    Text("4:12")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(theme.previewTextPrimary)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(theme.previewSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(theme.accentColor.opacity(0.12), lineWidth: 1)
                )
        )
    }

    private var previewHabitCard: some View {
        HStack(spacing: 10) {
            // Icon circle
            ZStack {
                Circle()
                    .fill(theme.accentColor.opacity(0.1))
                    .frame(width: 36, height: 36)
                Circle()
                    .fill(theme.accentColor.opacity(0.15))
                    .frame(width: 28, height: 28)
                Image(systemName: "timer")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(theme.accentColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Morning Meditation")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.previewTextPrimary)
                    .lineLimit(1)

                Text("5:00 remaining")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(theme.previewTextSecondary)
            }

            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(theme.previewSurface)
        )
    }

    private var previewNavControls: some View {
        HStack {
            // Previous button
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 8, weight: .semibold))
                Text("Previous")
                    .font(.system(size: 10, design: .rounded))
            }
            .foregroundStyle(theme.previewTextPrimary.opacity(0.6))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(theme.previewSurface)
                    .overlay(Capsule().stroke(theme.previewTextPrimary.opacity(0.1), lineWidth: 1))
            )

            Spacer()

            // Skip button
            HStack(spacing: 4) {
                Text("Skip")
                    .font(.system(size: 10, design: .rounded))
                Image(systemName: "forward.fill")
                    .font(.system(size: 8, weight: .semibold))
            }
            .foregroundStyle(theme.accentColor.opacity(0.8))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(theme.accentColor.opacity(0.08))
                    .overlay(Capsule().stroke(theme.accentColor.opacity(0.2), lineWidth: 1))
            )
        }
    }
}

// MARK: - Preview

#Preview {
    ThemeCustomizationView()
        .withDynamicTheme()
}
