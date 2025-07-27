import Foundation

/// Centralized persistence service for all app data
public protocol PersistenceServiceProtocol: Sendable {
    func save<T: Codable & Sendable>(_ object: T, forKey key: String) async throws
    func load<T: Codable & Sendable>(_ type: T.Type, forKey key: String) async throws -> T?
    func delete(forKey key: String) async
    func exists(forKey key: String) async -> Bool
}

/// UserDefaults-based implementation of PersistenceService
public final class UserDefaultsPersistenceService: PersistenceServiceProtocol, @unchecked Sendable {
    private let userDefaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    
    /// Initialize with custom UserDefaults (useful for testing)
    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
    }
    
    /// Save a Codable object to persistence
    public func save<T: Codable & Sendable>(_ object: T, forKey key: String) async throws {
        let data = try encoder.encode(object)
        userDefaults.set(data, forKey: key)
    }
    
    /// Load a Codable object from persistence
    public func load<T: Codable & Sendable>(_ type: T.Type, forKey key: String) async throws -> T? {
        guard let data = userDefaults.data(forKey: key) else {
            return nil
        }
        return try decoder.decode(type, from: data)
    }
    
    /// Delete an object from persistence
    public func delete(forKey key: String) async {
        userDefaults.removeObject(forKey: key)
    }
    
    /// Check if a key exists in persistence
    public func exists(forKey key: String) async -> Bool {
        userDefaults.object(forKey: key) != nil
    }
}

/// Persistence keys used throughout the app
public enum PersistenceKeys {
    public static let dayCategorySettings = "DayCategorySettings"
    public static let locationCategorySettings = "LocationCategorySettings"
    public static let routineTemplates = "RoutineTemplates"
}

/// Error types for persistence operations
public enum PersistenceError: Error, LocalizedError {
    case encodingFailed(Error)
    case decodingFailed(Error)
    case keyNotFound(String)
    
    public var errorDescription: String? {
        switch self {
        case .encodingFailed(let error):
            return "Failed to encode data: \(error.localizedDescription)"
        case .decodingFailed(let error):
            return "Failed to decode data: \(error.localizedDescription)"
        case .keyNotFound(let key):
            return "No data found for key: \(key)"
        }
    }
}