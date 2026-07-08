import WidgetKit
import SwiftUI
import HabitTrackerWidgetShared

// MARK: - Snapshot loading

private enum SnapshotLoader {
    static func load() -> WidgetSnapshot {
        WidgetSnapshotStore.shared.read() ?? .empty
    }
}

private extension Color {
    init(hex: String) {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") { value.removeFirst() }
        guard let int = UInt64(value, radix: 16) else {
            self = .accentColor
            return
        }
        let r, g, b, a: Double
        switch value.count {
        case 6:
            r = Double((int >> 16) & 0xFF) / 255
            g = Double((int >> 8) & 0xFF) / 255
            b = Double(int & 0xFF) / 255
            a = 1
        case 8:
            r = Double((int >> 24) & 0xFF) / 255
            g = Double((int >> 16) & 0xFF) / 255
            b = Double((int >> 8) & 0xFF) / 255
            a = Double(int & 0xFF) / 255
        default:
            self = .accentColor
            return
        }
        self = Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

// MARK: - Top Routine Widget

struct TopRoutineEntry: TimelineEntry {
    let date: Date
    let topRoutine: WidgetSnapshot.TopRoutine?
}

struct TopRoutineProvider: TimelineProvider {
    func placeholder(in context: Context) -> TopRoutineEntry {
        TopRoutineEntry(
            date: Date(),
            topRoutine: .init(name: "Morning", habitCount: 5, colorHex: "#4A90E2")
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (TopRoutineEntry) -> Void) {
        completion(TopRoutineEntry(date: Date(), topRoutine: SnapshotLoader.load().topRoutine))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TopRoutineEntry>) -> Void) {
        let entry = TopRoutineEntry(date: Date(), topRoutine: SnapshotLoader.load().topRoutine)
        let nextRefresh = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

struct TopRoutineWidgetView: View {
    let entry: TopRoutineEntry

    var body: some View {
        if let routine = entry.topRoutine {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Circle()
                        .fill(Color(hex: routine.colorHex))
                        .frame(width: 12, height: 12)
                    Text("Top Routine")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                Text(routine.name)
                    .font(.headline)
                    .lineLimit(2)
                Spacer()
                Text("\(routine.habitCount) \(routine.habitCount == 1 ? "habit" : "habits")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .widgetURL(routine.templateId.map { DeepLink.startURL(templateId: $0) })
        } else {
            VStack(spacing: 6) {
                Image(systemName: "list.bullet.rectangle")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("No routines yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct TopRoutineWidget: Widget {
    let kind = "TopRoutineWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TopRoutineProvider()) { entry in
            TopRoutineWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Top Routine")
        .description("Shows your highest-priority routine.")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - Paused Routine Widget

struct PausedRoutineEntry: TimelineEntry {
    let date: Date
    let paused: WidgetSnapshot.PausedSession?
}

struct PausedRoutineProvider: TimelineProvider {
    func placeholder(in context: Context) -> PausedRoutineEntry {
        PausedRoutineEntry(
            date: Date(),
            paused: .init(routineName: "Morning", pausedAt: Date(), currentStepIndex: 2, totalSteps: 5)
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (PausedRoutineEntry) -> Void) {
        completion(PausedRoutineEntry(date: Date(), paused: SnapshotLoader.load().pausedSession))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PausedRoutineEntry>) -> Void) {
        let entry = PausedRoutineEntry(date: Date(), paused: SnapshotLoader.load().pausedSession)
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

struct PausedRoutineWidgetView: View {
    let entry: PausedRoutineEntry

    var body: some View {
        if let paused = entry.paused {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "pause.circle.fill")
                        .foregroundStyle(.orange)
                    Text("Paused")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                Text(paused.routineName)
                    .font(.headline)
                    .lineLimit(2)
                Spacer()
                ProgressView(value: Double(paused.currentStepIndex), total: Double(max(paused.totalSteps, 1)))
                    .tint(.orange)
                Text("Step \(paused.currentStepIndex + 1) of \(paused.totalSteps)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .widgetURL(paused.sessionId.map { DeepLink.resumeURL(sessionId: $0) })
        } else {
            VStack(spacing: 6) {
                Image(systemName: "checkmark.circle")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("Nothing paused")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct PausedRoutineWidget: Widget {
    let kind = "PausedRoutineWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PausedRoutineProvider()) { entry in
            PausedRoutineWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Paused Routine")
        .description("Resume where you left off.")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - Streaks Widget

struct StreaksEntry: TimelineEntry {
    let date: Date
    let streaks: [WidgetSnapshot.StreakEntry]
}

struct StreaksProvider: TimelineProvider {
    func placeholder(in context: Context) -> StreaksEntry {
        StreaksEntry(
            date: Date(),
            streaks: [
                .init(routineName: "Morning", totalStreak: 12, target: 5, completedThisWeek: 4),
                .init(routineName: "Workout", totalStreak: 7, target: 3, completedThisWeek: 2),
                .init(routineName: "Reading", totalStreak: 3, target: 7, completedThisWeek: 3)
            ]
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (StreaksEntry) -> Void) {
        completion(StreaksEntry(date: Date(), streaks: SnapshotLoader.load().streaks))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StreaksEntry>) -> Void) {
        let entry = StreaksEntry(date: Date(), streaks: SnapshotLoader.load().streaks)
        let nextRefresh = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

struct StreaksWidgetView: View {
    let entry: StreaksEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if entry.streaks.isEmpty {
            VStack(spacing: 6) {
                Image(systemName: "flame")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("No streaks yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if family == .systemSmall {
            smallBody(top: entry.streaks.first!)
        } else {
            mediumBody(rows: Array(entry.streaks.prefix(3)))
        }
    }

    private func smallBody(top: WidgetSnapshot.StreakEntry) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(.orange)
                Text("Top streak")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            Text(top.routineName)
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(1)
            Spacer()
            Text("\(top.totalStreak)")
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            Text("\(top.completedThisWeek)/\(top.target) this week")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func mediumBody(rows: [WidgetSnapshot.StreakEntry]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(.orange)
                Text("Streaks")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                streakRow(row)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func streakRow(_ row: WidgetSnapshot.StreakEntry) -> some View {
        HStack(spacing: 8) {
            Text(row.routineName)
                .font(.subheadline)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("\(row.completedThisWeek)/\(row.target)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            HStack(spacing: 3) {
                Image(systemName: "flame.fill")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                Text("\(row.totalStreak)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .monospacedDigit()
            }
            .frame(width: 44, alignment: .trailing)
        }
    }
}

struct StreaksWidget: Widget {
    let kind = "StreaksWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StreaksProvider()) { entry in
            StreaksWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Streaks")
        .description("Track your top routine streaks.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
