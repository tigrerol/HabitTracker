import SwiftUI

// MARK: - Settings View

public struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.themeManager) private var themeManager
    @State private var showingThemeCustomization = false
    @State private var showingContextSettings = false
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            List {
                // Appearance Section
                Section("Appearance") {
                    Button {
                        showingThemeCustomization = true
                        HapticManager.trigger(.light)
                    } label: {
                        HStack {
                            Image(systemName: "paintpalette.fill")
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [themeManager.currentAccentColor, themeManager.currentAccentColor.opacity(0.7)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Appearance")
                                    .customSubheadline()

                                Text(themeManager.currentTheme.displayName + " · " + themeManager.currentTheme.modeLabel)
                                    .customCaption()
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            // Current theme accent swatch
                            Circle()
                                .fill(themeManager.currentAccentColor)
                                .frame(width: 20, height: 20)
                                .overlay(
                                    Circle()
                                        .stroke(themeManager.currentAccentColor.opacity(0.3), lineWidth: 1)
                                )
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                
                // Smart Routine Section  
                Section("Smart Routine") {
                    Button {
                        showingContextSettings = true
                        HapticManager.trigger(.light)
                    } label: {
                        HStack {
                            Image(systemName: "gearshape.fill")
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [themeManager.currentAccentColor.opacity(0.8), themeManager.currentAccentColor.opacity(0.6)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Context Settings")
                                    .customSubheadline()
                                
                                Text("Time slots, day types, and locations")
                                    .customCaption()
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                
                // App Info Section
                Section("About") {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [themeManager.currentAccentColor.opacity(0.7), themeManager.currentAccentColor.opacity(0.5)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("HabitTracker")
                                .customSubheadline()
                            
                            Text("Version 1.0")
                                .customCaption()
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                }
            }
            .navigationTitle("Settings")
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
        .sheet(isPresented: $showingThemeCustomization) {
            ThemeCustomizationView()
        }
        .sheet(isPresented: $showingContextSettings) {
            ContextSettingsView()
        }
    }
}

// MARK: - Settings Button Component

public struct SettingsButton: View {
    @State private var showingSettings = false
    
    public init() {}
    
    public var body: some View {
        Button {
            showingSettings = true
            HapticManager.trigger(.light)
        } label: {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 20))
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }
}

#Preview {
    SettingsView()
        .withDynamicTheme()
}