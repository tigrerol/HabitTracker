import Foundation
import SwiftUI

/// Service for exporting app data to JSON format
@MainActor
public final class DataExportService {
    private let routineService: RoutineService
    
    public init(routineService: RoutineService) {
        self.routineService = routineService
    }
    
    /// Export all app data to JSON format
    public func exportData() -> ExportData {
        return ExportData(
            routines: routineService.templates,
            customLocations: routineService.routineSelector.locationCoordinator.getAllCustomLocations(),
            savedLocations: routineService.routineSelector.locationCoordinator.getSavedLocations(),
            dayCategories: DayCategoryManager.shared.getAllCategories(),
            exportDate: Date(),
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        )
    }
    
    /// Convert export data to JSON string
    public func exportToJSON() throws -> String {
        let exportData = exportData()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        let jsonData = try encoder.encode(exportData)
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw ExportError.encodingFailed
        }
        
        return jsonString
    }
    
    /// Generate filename for export
    public func generateExportFilename() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        return "HabitTracker_Export_\(timestamp).json"
    }
    
    /// Import data from JSON string
    public func importFromJSON(_ jsonString: String) throws -> ImportResult {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw ImportError.invalidJSON
        }
        
        let exportData = try decoder.decode(ExportData.self, from: jsonData)
        return try processImportData(exportData)
    }
    
    /// Import data from file URL
    public func importFromFile(_ fileURL: URL) throws -> ImportResult {
        let jsonString = try String(contentsOf: fileURL, encoding: .utf8)
        return try importFromJSON(jsonString)
    }
    
    /// Process imported data and merge with existing data
    private func processImportData(_ importData: ExportData) throws -> ImportResult {
        var result = ImportResult()
        
        // Import routines
        var importedRoutines = 0
        var skippedRoutines = 0
        
        for routine in importData.routines {
            // Check if routine with same name already exists
            if routineService.templates.contains(where: { $0.name == routine.name }) {
                skippedRoutines += 1
            } else {
                // Create new routine with new ID to avoid conflicts
                let newRoutine = RoutineTemplate(
                    id: UUID(),
                    name: routine.name,
                    description: routine.description,
                    habits: routine.habits,
                    color: routine.color,
                    isDefault: routine.isDefault,
                    createdAt: routine.createdAt,
                    lastUsedAt: routine.lastUsedAt,
                    contextRule: routine.contextRule
                )
                routineService.addTemplate(newRoutine)
                importedRoutines += 1
            }
        }
        
        result.routinesImported = importedRoutines
        result.routinesSkipped = skippedRoutines
        
        // Import custom locations
        var importedLocations = 0
        var skippedLocations = 0
        
        for customLocation in importData.customLocations {
            let existingLocations = routineService.routineSelector.locationCoordinator.getAllCustomLocations()
            if existingLocations.contains(where: { $0.name == customLocation.name }) {
                skippedLocations += 1
            } else {
                Task {
                    _ = await routineService.routineSelector.locationCoordinator.createCustomLocation(
                        name: customLocation.name,
                        icon: customLocation.icon
                    )
                }
                importedLocations += 1
            }
        }
        
        result.customLocationsImported = importedLocations
        result.customLocationsSkipped = skippedLocations
        
        // Import saved locations
        var importedSavedLocations = 0
        for (locationType, savedLocation) in importData.savedLocations {
            let existingSavedLocations = routineService.routineSelector.locationCoordinator.getSavedLocations()
            if existingSavedLocations[locationType] == nil {
                Task {
                    try? await routineService.routineSelector.locationCoordinator.saveLocation(
                        savedLocation.clLocation,
                        as: locationType,
                        name: savedLocation.name,
                        radius: savedLocation.radius
                    )
                }
                importedSavedLocations += 1
            }
        }
        
        result.savedLocationsImported = importedSavedLocations
        
        // Import day categories
        var importedDayCategories = 0
        for dayCategory in importData.dayCategories {
            let existingCategories = DayCategoryManager.shared.getAllCategories()
            if !existingCategories.contains(where: { $0.name == dayCategory.name }) {
                DayCategoryManager.shared.addCustomCategory(dayCategory)
                importedDayCategories += 1
            }
        }
        
        result.dayCategoriesImported = importedDayCategories
        result.exportDate = importData.exportDate
        result.sourceAppVersion = importData.appVersion
        
        return result
    }
}

/// Data structure for JSON export
public struct ExportData: Codable {
    public let routines: [RoutineTemplate]
    public let customLocations: [CustomLocation]
    public let savedLocations: [LocationType: SavedLocation]
    public let dayCategories: [DayCategory]
    public let exportDate: Date
    public let appVersion: String
    
    enum CodingKeys: String, CodingKey {
        case routines
        case customLocations
        case savedLocations
        case dayCategories
        case exportDate
        case appVersion
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(routines, forKey: .routines)
        try container.encode(customLocations, forKey: .customLocations)
        
        // Convert saved locations dictionary to array for JSON export
        let savedLocationArray = savedLocations.map { (key, value) in
            SavedLocationExport(locationType: key.rawValue, location: value)
        }
        try container.encode(savedLocationArray, forKey: .savedLocations)
        
        try container.encode(dayCategories, forKey: .dayCategories)
        try container.encode(exportDate, forKey: .exportDate)
        try container.encode(appVersion, forKey: .appVersion)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        routines = try container.decode([RoutineTemplate].self, forKey: .routines)
        customLocations = try container.decode([CustomLocation].self, forKey: .customLocations)
        
        // Convert saved location array back to dictionary
        let savedLocationArray = try container.decode([SavedLocationExport].self, forKey: .savedLocations)
        var locationDict: [LocationType: SavedLocation] = [:]
        for item in savedLocationArray {
            if let locationType = LocationType(rawValue: item.locationType) {
                locationDict[locationType] = item.location
            }
        }
        savedLocations = locationDict
        
        dayCategories = try container.decode([DayCategory].self, forKey: .dayCategories)
        exportDate = try container.decode(Date.self, forKey: .exportDate)
        appVersion = try container.decode(String.self, forKey: .appVersion)
    }
    
    public init(routines: [RoutineTemplate], customLocations: [CustomLocation], savedLocations: [LocationType: SavedLocation], dayCategories: [DayCategory], exportDate: Date, appVersion: String) {
        self.routines = routines
        self.customLocations = customLocations
        self.savedLocations = savedLocations
        self.dayCategories = dayCategories
        self.exportDate = exportDate
        self.appVersion = appVersion
    }
}

/// Helper structure for encoding saved locations
private struct SavedLocationExport: Codable {
    let locationType: String
    let location: SavedLocation
}

/// Export-related errors
public enum ExportError: LocalizedError {
    case encodingFailed
    case noDataToExport
    
    public var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "Failed to encode data to JSON"
        case .noDataToExport:
            return "No data available to export"
        }
    }
}

/// Import-related errors
public enum ImportError: LocalizedError {
    case invalidJSON
    case invalidFileFormat
    case decodingFailed
    case incompatibleVersion
    
    public var errorDescription: String? {
        switch self {
        case .invalidJSON:
            return "Invalid JSON format"
        case .invalidFileFormat:
            return "File format not recognized"
        case .decodingFailed:
            return "Failed to decode import data"
        case .incompatibleVersion:
            return "Import file from incompatible app version"
        }
    }
}

/// Result of import operation
public struct ImportResult {
    public var routinesImported: Int = 0
    public var routinesSkipped: Int = 0
    public var customLocationsImported: Int = 0
    public var customLocationsSkipped: Int = 0
    public var savedLocationsImported: Int = 0
    public var dayCategoriesImported: Int = 0
    public var exportDate: Date?
    public var sourceAppVersion: String?
    
    public var totalItemsImported: Int {
        return routinesImported + customLocationsImported + savedLocationsImported + dayCategoriesImported
    }
    
    public var totalItemsSkipped: Int {
        return routinesSkipped + customLocationsSkipped
    }
    
    public var hasImportedItems: Bool {
        return totalItemsImported > 0
    }
}