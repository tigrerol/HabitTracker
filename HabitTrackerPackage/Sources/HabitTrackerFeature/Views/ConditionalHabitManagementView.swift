import SwiftUI

/// Management view for conditional habits analytics and data
@MainActor
public struct ConditionalHabitManagementView: View {
    @State private var conditionalService = ConditionalHabitService.shared
    @State private var selectedTab = 0
    @State private var showingExportSheet = false
    @State private var showingImportSheet = false
    @State private var exportData: Data?
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            TabView(selection: $selectedTab) {
                // Analytics Tab
                analyticsView
                    .tabItem {
                        Image(systemName: "chart.bar")
                        Text("Analytics")
                    }
                    .tag(0)
                
                // Responses Tab
                responsesView
                    .tabItem {
                        Image(systemName: "list.bullet")
                        Text("Responses")
                    }
                    .tag(1)
                
                // Management Tab
                managementView
                    .tabItem {
                        Image(systemName: "gear")
                        Text("Management")
                    }
                    .tag(2)
            }
            .navigationTitle("Conditional Habits")
        }
        .sheet(isPresented: $showingExportSheet) {
            if let data = exportData {
                ActivityView(activityItems: [data])
            }
        }
    }
    
    @ViewBuilder
    private var analyticsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Overview Stats
                overviewStatsSection
                
                // Recent Activity
                if !conditionalService.responses.isEmpty {
                    recentActivitySection
                }
            }
            .padding()
        }
    }
    
    @ViewBuilder
    private var overviewStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Overview")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                StatCard(
                    title: "Total Responses",
                    value: "\(conditionalService.analytics.totalResponses)",
                    icon: "bubble.left.and.bubble.right"
                )
                
                StatCard(
                    title: "Completed",
                    value: "\(conditionalService.analytics.completedResponses)",
                    icon: "checkmark.circle"
                )
                
                StatCard(
                    title: "Skipped",
                    value: "\(conditionalService.analytics.skippedResponses)",
                    icon: "xmark.circle"
                )
                
                StatCard(
                    title: "Skip Rate",
                    value: String(format: "%.1f%%", conditionalService.analytics.skipRate * 100),
                    icon: "percent"
                )
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    @ViewBuilder
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Activity")
                .font(.headline)
            
            ForEach(conditionalService.responses.suffix(5).reversed(), id: \.id) { response in
                ResponseRow(response: response)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    @ViewBuilder
    private var responsesView: some View {
        List {
            ForEach(conditionalService.responses.sorted { $0.timestamp > $1.timestamp }, id: \.id) { response in
                ResponseDetailRow(response: response)
            }
        }
        .listStyle(.plain)
    }
    
    @ViewBuilder
    private var managementView: some View {
        VStack(spacing: 20) {
            // Export/Import Section
            VStack(alignment: .leading, spacing: 12) {
                Text("Data Management")
                    .font(.headline)
                
                HStack(spacing: 12) {
                    Button("Export Data") {
                        exportResponses()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Clear All") {
                        conditionalService.clearAllResponses()
                    }
                    .buttonStyle(.bordered)
                    .foregroundStyle(.red)
                }
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            
            // Validation Tools
            VStack(alignment: .leading, spacing: 12) {
                Text("Tools")
                    .font(.headline)
                
                Text("Use this section to validate conditional habit configurations and analyze response patterns.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            
            Spacer()
        }
        .padding()
    }
    
    private func exportResponses() {
        do {
            exportData = try conditionalService.exportResponses()
            showingExportSheet = true
        } catch {
            // Handle error - could show an alert
            LoggingService.shared.error(
                "Failed to export conditional habit data",
                category: .data,
                metadata: ["error": error.localizedDescription]
            )
        }
    }
}

/// Card view for displaying statistics
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)
            
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
    }
}

/// Row view for displaying a response summary
struct ResponseRow: View {
    let response: ConditionalResponse
    
    var body: some View {
        HStack {
            Image(systemName: response.wasSkipped ? "xmark.circle" : "checkmark.circle")
                .foregroundStyle(response.wasSkipped ? .orange : .green)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(response.selectedOptionText)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(response.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

/// Detailed row view for displaying a response
struct ResponseDetailRow: View {
    let response: ConditionalResponse
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(response.selectedOptionText)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Image(systemName: response.wasSkipped ? "xmark.circle.fill" : "checkmark.circle.fill")
                    .foregroundStyle(response.wasSkipped ? .orange : .green)
            }
            
            Text(response.question)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            
            Text(response.timestamp.formatted(date: .abbreviated, time: .shortened))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

/// Activity view for sharing data
struct ActivityView: View {
    let activityItems: [Any]
    
    var body: some View {
        #if canImport(UIKit)
        ActivityViewRepresentable(activityItems: activityItems)
        #else
        VStack {
            Text("Export functionality available on iOS")
                .foregroundStyle(.secondary)
            Button("Save to Documents") {
                // Placeholder for macOS export
            }
        }
        .padding()
        #endif
    }
}

#if canImport(UIKit)
/// UIKit wrapper for activity view
struct ActivityViewRepresentable: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif

#Preview {
    ConditionalHabitManagementView()
}