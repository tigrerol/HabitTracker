import SwiftUI

/// Debug view for monitoring actor performance and testing
@MainActor
public struct ActorDebugView: View {
    private let locationService: LocationService
    @State private var debugService = ActorDebugService.shared
    @State private var isTestRunning = false
    @State private var lastTestResult: String = ""
    @State private var showingDetailReport = false
    @State private var selectedActorType = "LocationService"
    
    private let actorTypes = ["LocationService", "RoutineService", "ErrorPresentationService"]
    
    public init(locationService: LocationService) {
        self.locationService = locationService
    }
    
    public var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Debug Control Section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Debug Mode")
                            .font(.headline)
                        Spacer()
                        Toggle("Enabled", isOn: $debugService.isEnabled)
                    }
                    
                    Picker("Actor Type", selection: $selectedActorType) {
                        ForEach(actorTypes, id: \.self) { actorType in
                            Text(actorType).tag(actorType)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    HStack {
                        Button("Clear Logs") {
                            debugService.clearLogs()
                        }
                        .buttonStyle(.bordered)
                        
                        Spacer()
                        
                        Button("View Report") {
                            showingDetailReport = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                
                // Test Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Actor Tests")
                        .font(.headline)
                    
                    if selectedActorType == "LocationService" {
                        locationServiceTestButtons
                    }
                    
                    if isTestRunning {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Running test...")
                                .font(.caption)
                        }
                    }
                    
                    if !lastTestResult.isEmpty {
                        ScrollView {
                            Text(lastTestResult)
                                .font(.system(.caption, design: .monospaced))
                                .padding()
                                .background(.gray.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                        }
                        .frame(maxHeight: 200)
                    }
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                
                // Quick Stats
                if debugService.isEnabled {
                    quickStatsView
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Actor Debug")
            .sheet(isPresented: $showingDetailReport) {
                DetailReportView(debugService: debugService)
            }
        }
    }
    
    @ViewBuilder
    private var locationServiceTestButtons: some View {
        VStack(spacing: 8) {
            Button("Test State Snapshot") {
                runLocationTest(.stateSnapshot)
            }
            .buttonStyle(.bordered)
            .disabled(isTestRunning)
            
            Button("Test Concurrent Access") {
                runLocationTest(.concurrentAccess)
            }
            .buttonStyle(.bordered)
            .disabled(isTestRunning)
            
            Button("Test Memory Management") {
                runLocationTest(.memoryManagement)
            }
            .buttonStyle(.bordered)
            .disabled(isTestRunning)
            
            Button("Test Actor Isolation") {
                runLocationTest(.actorIsolation)
            }
            .buttonStyle(.bordered)
            .disabled(isTestRunning)
        }
    }
    
    @ViewBuilder
    private var quickStatsView: some View {
        let debugInfo = debugService.getDebugInfo(for: selectedActorType)
        
        VStack(alignment: .leading, spacing: 8) {
            Text("Quick Stats")
                .font(.headline)
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Operations: \(debugInfo.totalOperations)")
                    Text("Avg Duration: \(String(format: "%.2f", debugInfo.averageDuration))ms")
                }
                .font(.caption)
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Last Activity:")
                    Text(debugInfo.lastActivity?.formatted(date: .omitted, time: .standard) ?? "None")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    private enum LocationTestType {
        case stateSnapshot
        case concurrentAccess
        case memoryManagement
        case actorIsolation
    }
    
    private func runLocationTest(_ testType: LocationTestType) {
        Task {
            isTestRunning = true
            defer { isTestRunning = false }
            
            let debugInterface = LocationServiceDebugInterface(locationService: locationService)
            
            switch testType {
            case .stateSnapshot:
                let result = await debugInterface.getStateSnapshot()
                lastTestResult = formatStateSnapshot(result)
                
            case .concurrentAccess:
                let result = await debugInterface.testConcurrentAccess()
                lastTestResult = formatConcurrencyResult(result)
                
            case .memoryManagement:
                let result = await debugInterface.testMemoryManagement()
                lastTestResult = formatMemoryResult(result)
                
            case .actorIsolation:
                let result = await debugInterface.testActorIsolation()
                lastTestResult = formatIsolationResult(result)
            }
        }
    }
    
    private func formatStateSnapshot(_ result: LocationServiceStateSnapshot) -> String {
        return """
        State Snapshot (Duration: \(String(format: "%.2f", result.operationDuration))ms)
        Location: \(result.currentLocation?.latitude ?? 0), \(result.currentLocation?.longitude ?? 0)
        Type: \(result.locationType.rawValue)
        Extended: \(String(describing: result.extendedLocationType))
        Saved Locations: \(result.savedLocationsCount)
        Custom Locations: \(result.customLocationsCount)
        Captured: \(result.captureTime.formatted())
        """
    }
    
    private func formatConcurrencyResult(_ result: ConcurrencyTestResult) -> String {
        return """
        Concurrency Test
        Operations: \(result.operationCount)
        Total Duration: \(String(format: "%.2f", result.totalDuration))ms
        Average Duration: \(String(format: "%.2f", result.averageOperationDuration))ms
        Max Duration: \(String(format: "%.2f", result.maxOperationDuration))ms
        """
    }
    
    private func formatMemoryResult(_ result: MemoryTestResult) -> String {
        return """
        Memory Test (Duration: \(String(format: "%.2f", result.duration))ms)
        State Consistent: \(result.isStateConsistent ? "✅" : "❌")
        Initial Type: \(result.initialSnapshot.locationType.rawValue)
        Final Type: \(result.finalSnapshot.locationType.rawValue)
        """
    }
    
    private func formatIsolationResult(_ result: ActorIsolationTestResult) -> String {
        return """
        Actor Isolation Test
        Operations: \(result.operationTimestamps.count)
        Average Gap: \(String(format: "%.4f", result.averageGap))s
        Max Gap: \(String(format: "%.4f", result.maxGap))s
        Serialized: \(result.averageGap > 0 ? "✅" : "❌")
        """
    }
}

/// Detail report view for comprehensive debug information
@MainActor
struct DetailReportView: View {
    let debugService: ActorDebugService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                Text(debugService.getDebugReport())
                    .font(.system(.body, design: .monospaced))
                    .padding()
            }
            .navigationTitle("Debug Report")
            #if canImport(UIKit)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: {
                    #if canImport(UIKit)
                    .topBarTrailing
                    #else
                    .automatic
                    #endif
                }()) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    ActorDebugView(locationService: LocationService())
}