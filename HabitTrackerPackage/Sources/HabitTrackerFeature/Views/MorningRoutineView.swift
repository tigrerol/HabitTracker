import SwiftUI

/// Main coordination view for the morning routine feature
@MainActor
public struct MorningRoutineView: View {
    @State private var routineService = RoutineService()
    
    public init() {}
    
    public var body: some View {
        Group {
            if routineService.currentSession != nil {
                RoutineExecutionView()
            } else {
                SmartTemplateSelectionView()
            }
        }
        .environment(routineService)
    }
}

#Preview {
    MorningRoutineView()
}