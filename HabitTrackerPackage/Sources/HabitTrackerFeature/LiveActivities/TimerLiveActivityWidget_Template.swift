// MARK: - Widget Extension Template
// This file shows how to implement Live Activity widgets in a Widget Extension target
// Copy this code to your Widget Extension once you create one in Xcode

/*
import ActivityKit
import SwiftUI
import WidgetKit
import HabitTrackerFeature

// MARK: - Live Activity Widget Implementation

@available(iOS 16.1, *)
struct TimerLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TimerActivityAttributes.self) { context in
            // Lock Screen presentation
            LockScreenLiveActivityView(context: context)
        } dynamicIsland: { context in
            // Dynamic Island presentation
            DynamicIsland {
                // Expanded presentation
                DynamicIslandExpandedRegion(.leading) {
                    HabitIconView(
                        name: context.state.habitName,
                        color: Color(hex: context.state.habitColor) ?? .blue
                    )
                }
                DynamicIslandExpandedRegion(.trailing) {
                    TimerProgressView(
                        progress: context.state.currentProgress,
                        timeRemaining: context.state.timeRemaining
                    )
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HabitTimerControlsView(
                        habitName: context.state.habitName,
                        isRunning: context.state.isRunning,
                        progress: context.state.currentProgress
                    )
                }
            } compactLeading: {
                // Compact leading presentation (left side of Dynamic Island)
                Image(systemName: "timer")
                    .foregroundColor(Color(hex: context.state.habitColor) ?? .blue)
            } compactTrailing: {
                // Compact trailing presentation (right side of Dynamic Island)
                Text(context.state.timeRemaining.formattedCountdown)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            } minimal: {
                // Minimal presentation (when multiple activities are active)
                Image(systemName: "timer")
                    .foregroundColor(Color(hex: context.state.habitColor) ?? .blue)
            }
        }
    }
}

// MARK: - Lock Screen Live Activity View

struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<TimerActivityAttributes>
    
    var body: some View {
        HStack(spacing: 16) {
            // Habit Icon and Name
            VStack(alignment: .leading, spacing: 4) {
                HabitIconView(
                    name: context.state.habitName,
                    color: Color(hex: context.state.habitColor) ?? .blue
                )
                
                Text(context.state.habitName)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                
                Text(context.state.isRunning ? "In Progress" : "Paused")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Timer Progress
            VStack(alignment: .trailing, spacing: 8) {
                // Time Remaining
                Text(context.state.timeRemaining.formattedCountdown)
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundColor(context.state.timeRemaining <= 30 ? .red : .primary)
                
                // Progress Bar
                ProgressView(value: context.state.currentProgress)
                    .progressViewStyle(LinearProgressViewStyle(tint: Color(hex: context.state.habitColor) ?? .blue))
                    .frame(width: 120)
                
                // Progress Percentage
                Text("\(Int(context.state.currentProgress * 100))%")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Supporting Views

struct HabitIconView: View {
    let name: String
    let color: Color
    
    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.2))
                .frame(width: 40, height: 40)
            
            Image(systemName: "timer")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(color)
        }
    }
}

struct TimerProgressView: View {
    let progress: Double
    let timeRemaining: TimeInterval
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(timeRemaining.formattedCountdown)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(timeRemaining <= 30 ? .red : .primary)
            
            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                .frame(width: 80)
        }
    }
}

struct HabitTimerControlsView: View {
    let habitName: String
    let isRunning: Bool
    let progress: Double
    
    var body: some View {
        HStack(spacing: 12) {
            Text(habitName)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)
            
            Spacer()
            
            Text("\(Int(progress * 100))% Complete")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Widget Bundle Registration

@available(iOS 16.1, *)
@main
struct HabitTrackerLiveActivities: WidgetBundle {
    var body: some Widget {
        TimerLiveActivityWidget()
    }
}

// MARK: - Color Extension for Hex Support

extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        
        guard Scanner(string: hex).scanHexInt64(&int) else {
            return nil
        }
        
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
*/