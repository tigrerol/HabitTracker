import Foundation
import HabitTrackerWidgetShared

/// App-wide navigation intents from outside the UI (deep links, widget taps).
/// A destination parks in `pendingDestination` until a view consumes it —
/// necessary because on cold start the link arrives before templates and
/// paused sessions have loaded.
@MainActor
@Observable
public final class Router {
    public static let shared = Router()

    public enum Destination: Equatable, Sendable {
        case startTemplate(UUID)
        case resumeSession(UUID)
    }

    public private(set) var pendingDestination: Destination?

    public init() {}

    /// Parse a deep-link URL; returns whether it was recognized.
    /// Formats: habittracker://start/<templateId>, habittracker://resume/<sessionId>
    @discardableResult
    public func handle(url: URL) -> Bool {
        LoggingService.shared.info("Deep link received", category: .app, metadata: ["url": url.absoluteString])
        guard url.scheme?.lowercased() == DeepLink.scheme else { return false }
        guard let idString = url.pathComponents.first(where: { $0 != "/" }),
              let id = UUID(uuidString: idString) else {
            LoggingService.shared.error("Deep link not parseable", category: .app, metadata: ["url": url.absoluteString])
            return false
        }

        switch url.host?.lowercased() {
        case "start":
            pendingDestination = .startTemplate(id)
            return true
        case "resume":
            pendingDestination = .resumeSession(id)
            return true
        default:
            LoggingService.shared.error("Deep link with unknown host", category: .app, metadata: ["url": url.absoluteString])
            return false
        }
    }

    /// Take the pending destination, clearing it. Call only when ready to act.
    public func consume() -> Destination? {
        defer { pendingDestination = nil }
        return pendingDestination
    }
}
