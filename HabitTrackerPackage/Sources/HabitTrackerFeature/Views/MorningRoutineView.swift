import SwiftUI

/// Root view: two-tab shell (Today · Streaks) that a running routine takes over full-screen
@MainActor
public struct MorningRoutineView: View {
    @State private var routineService = RoutineService.shared

    public init() {}

    public var body: some View {
        Group {
            if routineService.currentSession != nil {
                RoutineExecutionView()
                    .transition(TransitionEffects.slideInFromRight)
            } else {
                mainTabs
                    .transition(TransitionEffects.scaleAndFade)
            }
        }
        .animation(AnimationPresets.smoothSpring, value: routineService.currentSession != nil)
        .environment(routineService)
        .environment(DayCategoryManager.shared)
        .withDynamicTheme()
    }

    private var mainTabs: some View {
        TabView {
            Tab("Today", systemImage: "sun.max.fill") {
                SmartTemplateSelectionView()
            }

            Tab("Streaks", systemImage: "flame.fill") {
                NavigationStack {
                    StreaksView()
                }
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
    }
}

#Preview {
    MorningRoutineView()
}
