import SwiftUI

/// Main coordination view for the morning routine feature
@MainActor
public struct MorningRoutineView: View {
    @State private var routineService = RoutineService()
    @Namespace private var mainTransition
    
    public init() {}
    
    public var body: some View {
        Group {
            if routineService.currentSession != nil {
                RoutineExecutionView()
                    .transition(TransitionEffects.slideInFromRight)
            } else {
                SmartTemplateSelectionView()
                    .transition(TransitionEffects.scaleAndFade)
            }
        }
        .animation(AnimationPresets.smoothSpring, value: routineService.currentSession != nil)
        .environment(routineService)
        .environment(DayCategoryManager.shared)
        .withDynamicTheme()
    }
}

#Preview {
    MorningRoutineView()
}