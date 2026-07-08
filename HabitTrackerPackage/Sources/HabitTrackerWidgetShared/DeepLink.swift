import Foundation

/// URL scheme and link builders shared between the app and the widget.
/// Format: habittracker://start/<templateId>, habittracker://resume/<sessionId>
public enum DeepLink {
    public static let scheme = "habittracker"

    public static func startURL(templateId: UUID) -> URL {
        URL(string: "\(scheme)://start/\(templateId.uuidString)")!
    }

    public static func resumeURL(sessionId: UUID) -> URL {
        URL(string: "\(scheme)://resume/\(sessionId.uuidString)")!
    }
}
