import Testing
import Foundation
@testable import HabitTrackerFeature

struct TestSupportError: Error, CustomStringConvertible {
    let description: String
}

/// A UserDefaults suite isolated to one test, so parallel tests can't pollute
/// each other (or, worse, real standard defaults). Suite names are unique per
/// call; no cleanup is required.
func makeIsolatedDefaults(_ label: String = "test") throws -> UserDefaults {
    let suiteName = "\(label)-\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
        throw TestSupportError(description: "Could not create isolated UserDefaults suite \(suiteName)")
    }
    defaults.removePersistentDomain(forName: suiteName)
    return defaults
}

/// Assert that ErrorHandlingService.shared recorded an error after `start`
/// (optionally of a given category). Shared history also receives parallel
/// tests' errors, so existence-since-timestamp is the only stable assert.
@MainActor
func expectErrorRecorded(since start: Date, category: ErrorCategory? = nil, sourceLocation: SourceLocation = #_sourceLocation) {
    let matched = ErrorHandlingService.shared.getErrorHistory().contains { record in
        record.timestamp >= start && (category == nil || record.error.category == category)
    }
    #expect(matched, "expected an error\(category.map { " of category \($0)" } ?? "") recorded since \(start)", sourceLocation: sourceLocation)
}
