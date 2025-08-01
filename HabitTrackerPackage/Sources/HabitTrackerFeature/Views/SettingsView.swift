import SwiftUI

// MARK: - Settings View

public struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.themeManager) private var themeManager
    @State private var showingThemeCustomization = false
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            List {
                // Theme Section
                Section("Appearance") {
                    Button {
                        showingThemeCustomization = true
                        HapticManager.trigger(.light)
                    } label: {
                        HStack {
                            Image(systemName: "paintpalette.fill")
                                .foregroundColor(themeManager.currentAccentColor)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Theme Colors")
                                    .customSubheadline()
                                
                                Text("Customize accent colors")
                                    .customCaption()
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            // Current color preview
                            Circle()
                                .fill(themeManager.currentAccentColor)
                                .frame(width: 20, height: 20)
                            
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
                            .foregroundColor(.blue)
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