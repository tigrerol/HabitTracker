import SwiftUI

/// Root view: two-tab shell (Today · Streaks) that a running routine takes over full-screen
@MainActor
public struct MorningRoutineView: View {
    @State private var routineService = RoutineService.shared
    @State private var router = Router.shared
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
        .onOpenURL { url in
            // Fires when the deep link arrives while this view hierarchy is live;
            // the app target registers the same handler at the WindowGroup level
            // for delivery paths that bypass nested views.
            router.handle(url: url)
        }
        .task(id: router.pendingDestination) {
            guard router.pendingDestination != nil else { return }
            // On cold start the deep link can arrive before the async loads in
            // RoutineService.init finish — wait for templates before acting.
            for _ in 0..<50 where routineService.templates.isEmpty {
                try? await Task.sleep(for: .milliseconds(100))
            }
            handlePendingDeepLink()
        }
        .environment(routineService)
        .environment(router)
        .environment(DayCategoryManager.shared)
        .withDynamicTheme()
    }

    private func handlePendingDeepLink() {
        guard let destination = router.consume() else { return }
        LoggingService.shared.info("Handling deep link destination", category: .app, metadata: ["destination": String(describing: destination)])

        switch destination {
        case .startTemplate(let templateId):
            guard routineService.currentSession == nil,
                  let template = routineService.templates.first(where: { $0.id == templateId }) else { return }
            try? routineService.startSession(with: template)

        case .resumeSession(let sessionId):
            guard routineService.currentSession == nil else { return }
            try? routineService.resumeSession(withId: sessionId)
        }
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
