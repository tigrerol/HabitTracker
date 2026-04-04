import SwiftUI

/// A row displaying a paused routine session with resume and discard actions
struct PausedSessionRow: View {
    let snapshot: PausedSessionSnapshot
    let onResume: () -> Void
    let onDiscard: () -> Void

    var body: some View {
        Button(action: onResume) {
            HStack(spacing: 12) {
                // Color indicator
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(hex: snapshot.template.color) ?? .accentColor)
                    .frame(width: 4, height: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(snapshot.template.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)

                    HStack(spacing: 6) {
                        Text("\(snapshot.completedCount)/\(snapshot.totalCount)")
                        Text("•")
                        Text(pausedTimeAgo)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                // Progress ring
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 3)
                    Circle()
                        .trim(from: 0, to: snapshot.progress)
                        .stroke(Color(hex: snapshot.template.color) ?? .accentColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Image(systemName: "play.fill")
                        .font(.caption2)
                        .foregroundStyle(Color(hex: snapshot.template.color) ?? .accentColor)
                }
                .frame(width: 32, height: 32)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive, action: onDiscard) {
                Label(String(localized: "PausedSessionRow.Discard", bundle: .module), systemImage: "trash")
            }
        }
    }

    private var pausedTimeAgo: String {
        let interval = Date().timeIntervalSince(snapshot.pausedAt)
        if interval < 60 {
            return String(localized: "PausedSessionRow.JustNow", bundle: .module)
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return String(format: String(localized: "PausedSessionRow.MinutesAgo", bundle: .module), minutes)
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return String(format: String(localized: "PausedSessionRow.HoursAgo", bundle: .module), hours)
        } else {
            let days = Int(interval / 86400)
            return String(format: String(localized: "PausedSessionRow.DaysAgo", bundle: .module), days)
        }
    }
}
