import Testing
import Foundation
@testable import HabitTrackerFeature
import HabitTrackerWidgetShared

@Suite("Router Deep Link Tests")
struct RouterTests {

    @Test("Start URL round-trips through DeepLink builder and Router parser")
    @MainActor func startURLRoundTrip() {
        let router = Router()
        let templateId = UUID()

        let handled = router.handle(url: DeepLink.startURL(templateId: templateId))

        #expect(handled)
        #expect(router.pendingDestination == .startTemplate(templateId))
    }

    @Test("Resume URL round-trips through DeepLink builder and Router parser")
    @MainActor func resumeURLRoundTrip() {
        let router = Router()
        let sessionId = UUID()

        let handled = router.handle(url: DeepLink.resumeURL(sessionId: sessionId))

        #expect(handled)
        #expect(router.pendingDestination == .resumeSession(sessionId))
    }

    @Test("Consume returns the destination once, then nil")
    @MainActor func consumeClearsDestination() {
        let router = Router()
        let templateId = UUID()
        router.handle(url: DeepLink.startURL(templateId: templateId))

        #expect(router.consume() == .startTemplate(templateId))
        #expect(router.consume() == nil)
        #expect(router.pendingDestination == nil)
    }

    @Test("Foreign schemes and malformed URLs are rejected", arguments: [
        "https://example.com/start/00000000-0000-0000-0000-000000000000",
        "breathlab://start/00000000-0000-0000-0000-000000000000",
        "habittracker://start/not-a-uuid",
        "habittracker://start",
        "habittracker://unknown/00000000-0000-0000-0000-000000000000"
    ])
    @MainActor func rejectsInvalidURLs(urlString: String) throws {
        let router = Router()
        let url = try #require(URL(string: urlString))

        #expect(!router.handle(url: url))
        #expect(router.pendingDestination == nil)
    }
}
