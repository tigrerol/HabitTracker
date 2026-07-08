import SwiftUI

/// Root view: two-tab shell (Today · Streaks) that a running routine takes over full-screen
@MainActor
public struct MorningRoutineView: View {
    @State private var routineService = RoutineService.shared
    @Environment(\.scenePhase) private var scenePhase

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
        .onChange(of: scenePhase) { _, newPhase in
            // Snapshot the running session whenever the app leaves the foreground,
            // so progress survives if iOS terminates the app mid-routine.
            if newPhase == .inactive || newPhase == .background {
                Task { await routineService.autosaveCurrentSession() }
            }
        }
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
