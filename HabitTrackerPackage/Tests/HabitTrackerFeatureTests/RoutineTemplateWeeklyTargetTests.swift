import Testing
import Foundation
@testable import HabitTrackerFeature

@Suite("RoutineTemplate weeklyTarget")
struct RoutineTemplateWeeklyTargetTests {

    @Test func defaultIsNil() {
        let template = RoutineTemplate(name: "Morning")
        #expect(template.weeklyTarget == nil)
    }

    @Test func initStoresTarget() {
        let template = RoutineTemplate(name: "Morning", weeklyTarget: 5)
        #expect(template.weeklyTarget == 5)
    }

    @Test func codableRoundTripPreservesTarget() throws {
        let template = RoutineTemplate(name: "Morning", weeklyTarget: 3)
        let data = try JSONEncoder().encode(template)
        let decoded = try JSONDecoder().decode(RoutineTemplate.self, from: data)
        #expect(decoded.weeklyTarget == 3)
    }

    @Test func codableRoundTripHandlesNilTarget() throws {
        let template = RoutineTemplate(name: "Morning")
        let data = try JSONEncoder().encode(template)
        let decoded = try JSONDecoder().decode(RoutineTemplate.self, from: data)
        #expect(decoded.weeklyTarget == nil)
    }
}
