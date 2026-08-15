import SwiftUI

/// Root view: two-tab shell (Today · Streaks) that a running routine takes over full-screen
@MainActor
public struct MorningRoutineView: View {
    @State private var routineService = RoutineService.shared
    @State private var router = Router.shared
    @State private var showingStorageFailureAlert = false
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
            // Cold-start deep links can arrive before the async init loads
            // finish — wait for templates AND paused sessions before acting.
            await routineService.ensureLoaded()
            // A newer destination restarts this task; the cancelled run must
            // not consume the replacement's destination.
            guard !Task.isCancelled else { return }
            handlePendingDeepLink()
        }
        .task {
            if DataModelConfiguration.isUsingFallbackStore {
                showingStorageFailureAlert = true
            }
        }
        .alert("Your data couldn't be loaded", isPresented: $showingStorageFailureAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("HabitTracker couldn't open its database, so your routines from previous sessions aren't visible and changes made now won't be saved. Please restart the app; if this keeps happening, contact support before reinstalling.")
        }
        .environment(routineService)
        .environment(router)
        .environment(DayCategoryManager.shared)
        .environment(RoutineModeService.shared)
        .withDynamicTheme()
    }

    private func handlePendingDeepLink() {
        guard let destination = router.consume() else { return }
        LoggingService.shared.info("Handling deep link destination", category: .app, metadata: ["destination": String(describing: destination)])

        guard routineService.currentSession == nil else {
            LoggingService.shared.info("Deep link ignored — a session is already active", category: .app, metadata: ["destination": String(describing: destination)])
            return
        }

        switch destination {
        case .startTemplate(let templateId):
            guard let template = routineService.templates.first(where: { $0.id == templateId }) else {
                LoggingService.shared.error("Deep link dropped — template not found (stale widget?)", category: .app, metadata: ["templateId": templateId.uuidString])
                return
            }
            do {
                try routineService.startSession(with: template)
            } catch {
                LoggingService.shared.error("Deep link start failed", category: .app, metadata: ["error": String(describing: error)])
            }

        case .resumeSession(let sessionId):
            do {
                try routineService.resumeSession(withId: sessionId)
            } catch {
                LoggingService.shared.error("Deep link resume failed — paused session not found (stale widget?)", category: .app, metadata: ["sessionId": sessionId.uuidString])
            }
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
