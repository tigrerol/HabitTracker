import Foundation

public struct WidgetSnapshotStore: Sendable {
    public static let shared = WidgetSnapshotStore()

    private let appGroupIdentifier: String
    private let fileName: String

    public init(
        appGroupIdentifier: String = WidgetSharedConstants.appGroupIdentifier,
        fileName: String = WidgetSharedConstants.snapshotFileName
    ) {
        self.appGroupIdentifier = appGroupIdentifier
        self.fileName = fileName
    }

    private var fileURL: URL? {
        WidgetSharedConstants.containerURL(forAppGroup: appGroupIdentifier)?
            .appendingPathComponent(fileName, isDirectory: false)
    }

    public func write(_ snapshot: WidgetSnapshot) throws {
        guard let url = fileURL else { throw WidgetSnapshotStoreError.appGroupUnavailable }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(snapshot)
        try data.write(to: url, options: .atomic)
    }

    public func read() -> WidgetSnapshot? {
        guard let url = fileURL, let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(WidgetSnapshot.self, from: data)
    }
}

public enum WidgetSnapshotStoreError: Error {
    case appGroupUnavailable
}
