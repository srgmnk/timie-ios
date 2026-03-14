import AppIntents
import Foundation
import WidgetKit

enum HoursWidgetSharedStore {
    static let appGroupIdentifier = "group.ai.srgmnk.hours"
    static let citiesKey = "widget.savedCities"
    static let citiesFileName = "widget-saved-cities.json"
}

struct HoursWidgetCityRecord: Codable, Hashable, Sendable {
    let id: String
    let canonicalName: String
    let customDisplayName: String?
    let timeZoneIdentifier: String

    var visibleName: String {
        let trimmedCustomName = customDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmedCustomName.isEmpty ? canonicalName : trimmedCustomName
    }

    var timeZone: TimeZone {
        TimeZone(identifier: timeZoneIdentifier) ?? .current
    }
}

enum HoursWidgetCityReader {
    static func loadSavedCities() -> [HoursWidgetCityRecord] {
        if let fileData = loadSavedCitiesFromSharedFile(),
           let decodedCities = decodeCities(from: fileData) {
            return decodedCities
        }

        if let defaultsData = loadSavedCitiesFromSharedDefaults(),
           let decodedCities = decodeCities(from: defaultsData) {
            return decodedCities
        }

        return []
    }

    static func city(matching id: String?) -> HoursWidgetCityRecord? {
        let cities = loadSavedCities()
        guard !cities.isEmpty else { return nil }

        if let id, let matchedCity = cities.first(where: { $0.id == id }) {
            return matchedCity
        }

        return cities.first
    }

    private static func loadSavedCitiesFromSharedFile() -> Data? {
        guard let sharedDirectoryURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: HoursWidgetSharedStore.appGroupIdentifier
        ) else {
            return nil
        }

        let sharedFileURL = sharedDirectoryURL.appendingPathComponent(
            HoursWidgetSharedStore.citiesFileName,
            isDirectory: false
        )
        return try? Data(contentsOf: sharedFileURL)
    }

    private static func loadSavedCitiesFromSharedDefaults() -> Data? {
        UserDefaults(suiteName: HoursWidgetSharedStore.appGroupIdentifier)?
            .data(forKey: HoursWidgetSharedStore.citiesKey)
    }

    private static func decodeCities(from data: Data) -> [HoursWidgetCityRecord]? {
        try? JSONDecoder().decode([HoursWidgetCityRecord].self, from: data)
    }
}

struct HoursWidgetCityEntity: AppEntity, Identifiable, Hashable, Sendable {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Saved City")
    static var defaultQuery = HoursWidgetCityEntityQuery()

    let id: String
    let canonicalName: String
    let customDisplayName: String?
    let timeZoneIdentifier: String

    init(record: HoursWidgetCityRecord) {
        self.id = record.id
        self.canonicalName = record.canonicalName
        self.customDisplayName = record.customDisplayName
        self.timeZoneIdentifier = record.timeZoneIdentifier
    }

    var displayRepresentation: DisplayRepresentation {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = TimeZone(identifier: timeZoneIdentifier) ?? .current
        
        let timeString = formatter.string(from: Date())
        
        return DisplayRepresentation(
            title: LocalizedStringResource(stringLiteral: visibleName),
            subtitle: LocalizedStringResource(stringLiteral: timeString)
        )
    }

    var visibleName: String {
        let trimmedCustomName = customDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmedCustomName.isEmpty ? canonicalName : trimmedCustomName
    }
}

struct HoursWidgetCityEntityQuery: EntityQuery {
    func entities(for identifiers: [HoursWidgetCityEntity.ID]) async throws -> [HoursWidgetCityEntity] {
        let lookup = Set(identifiers)
        return HoursWidgetCityReader.loadSavedCities()
            .filter { lookup.contains($0.id) }
            .map(HoursWidgetCityEntity.init(record:))
    }

    func suggestedEntities() async throws -> [HoursWidgetCityEntity] {
        HoursWidgetCityReader.loadSavedCities().map(HoursWidgetCityEntity.init(record:))
    }

    func defaultResult() async -> HoursWidgetCityEntity? {
        HoursWidgetCityReader.loadSavedCities()
            .first
            .map(HoursWidgetCityEntity.init(record:))
    }
}

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Choose City" }
    static var description: IntentDescription { "Display the current time for one of your saved cities." }

    @Parameter(title: "City")
    var city: HoursWidgetCityEntity?
}
