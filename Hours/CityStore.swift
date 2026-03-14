import Foundation
import SwiftUI
import Combine
#if canImport(WidgetKit)
import WidgetKit
#endif

@MainActor
final class CityStore: ObservableObject {
    private struct WidgetCityRecord: Codable {
        let id: String
        let canonicalName: String
        let customDisplayName: String?
        let timeZoneIdentifier: String
    }

    private enum WidgetSharedStorage {
        static let appGroupIdentifier = "group.ai.srgmnk.hours"
        static let citiesKey = "widget.savedCities"
        static let citiesFileName = "widget-saved-cities.json"
    }

    @Published var cities: [City] = [] {
        didSet {
            guard !isLoading else { return }
            save()
        }
    }

    private let fileManager: FileManager
    private let citiesFileURL: URL
    private var isLoading = false

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        do {
            citiesFileURL = try Self.makeCitiesFileURL(fileManager: fileManager)
        } catch {
            let fallback = fileManager.temporaryDirectory.appendingPathComponent("cities.json", isDirectory: false)
            citiesFileURL = fallback
            log("Failed to resolve Application Support URL. Using fallback \(fallback.path). Error: \(error)")
        }
        load()
    }

    func load() {
        isLoading = true
        defer { isLoading = false }

        do {
            try ensureParentDirectoryExists()
            guard fileManager.fileExists(atPath: citiesFileURL.path) else {
                cities = []
                syncWidgetSharedCities()
                return
            }
            let data = try Data(contentsOf: citiesFileURL)
            let decoded = try JSONDecoder().decode([City].self, from: data)
            let migration = migrateCanonicalIdentitiesIfNeeded(decoded)
            cities = migration.cities
            syncWidgetSharedCities()
            if migration.didMigrate {
                save()
            }
        } catch {
            log("Failed to load cities from \(citiesFileURL.path). Error: \(error)")
            cities = []
            syncWidgetSharedCities()
        }
    }

    func save() {
        do {
            try ensureParentDirectoryExists()
            let encoder = JSONEncoder()
            #if DEBUG
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            #endif
            let data = try encoder.encode(cities)
            try data.write(to: citiesFileURL, options: [.atomic])
            syncWidgetSharedCities()
        } catch {
            log("Failed to save cities to \(citiesFileURL.path). Error: \(error)")
        }
    }

    private static func makeCitiesFileURL(fileManager: FileManager) throws -> URL {
        let applicationSupportDirectory = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return applicationSupportDirectory.appendingPathComponent("cities.json", isDirectory: false)
    }

    private func ensureParentDirectoryExists() throws {
        let directory = citiesFileURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }

    private func migrateCanonicalIdentitiesIfNeeded(_ cities: [City]) -> (cities: [City], didMigrate: Bool) {
        var didMigrate = false
        var migratedCities: [City] = []
        migratedCities.reserveCapacity(cities.count)

        for city in cities {
            let migratedID = migratedCanonicalID(for: city)
            if migratedID != city.id {
                didMigrate = true
            }

            let migratedCity = City(
                canonicalCity: CanonicalCity(
                    id: migratedID,
                    name: city.name,
                    timeZoneID: city.timeZoneID
                ),
                customDisplayName: city.customDisplayName
            )
            migratedCities.append(migratedCity)
        }

        return (migratedCities, didMigrate)
    }

    private func migratedCanonicalID(for city: City) -> String {
        if let customReferenceID = customReferenceCanonicalIDIfNeeded(for: city) {
            return customReferenceID
        }

        if city.id.hasPrefix("city:") {
            return city.id
        }

        if let providerCanonicalID = CitySearchProvider.shared.canonicalIdentityForStoredCity(
            city: city.name,
            timeZoneIdentifier: city.timeZoneID
        ) {
            return providerCanonicalID
        }

        return CitySearchItem.makeCanonicalIdentity(
            city: city.name,
            country: "",
            timeZoneIdentifier: city.timeZoneID
        )
    }

    private func customReferenceCanonicalIDIfNeeded(for city: City) -> String? {
        let canonicalID = city.id.lowercased()
        let timeZoneID = city.timeZoneID.lowercased()

        if canonicalID == "custom.utc" || timeZoneID == "etc/utc" || timeZoneID == "utc" {
            return "custom.utc"
        }
        if canonicalID == "custom.gmt" || timeZoneID == "gmt" {
            return "custom.gmt"
        }
        return nil
    }

    private func log(_ message: String) {
        #if DEBUG
        print("[CityStore] \(message)")
        #endif
    }

    private func syncWidgetSharedCities() {
        let sharedCities = cities.map {
            WidgetCityRecord(
                id: $0.id,
                canonicalName: $0.name,
                customDisplayName: $0.customDisplayName,
                timeZoneIdentifier: $0.timeZoneID
            )
        }

        do {
            let encoder = JSONEncoder()
            #if DEBUG
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            #endif
            let data = try encoder.encode(sharedCities)
            if let sharedDirectoryURL = fileManager.containerURL(
                forSecurityApplicationGroupIdentifier: WidgetSharedStorage.appGroupIdentifier
            ) {
                let sharedFileURL = sharedDirectoryURL.appendingPathComponent(
                    WidgetSharedStorage.citiesFileName,
                    isDirectory: false
                )
                try data.write(to: sharedFileURL, options: [.atomic])
            } else {
                log("Failed to open shared container for app group \(WidgetSharedStorage.appGroupIdentifier)")
            }

            if let sharedDefaults = UserDefaults(suiteName: WidgetSharedStorage.appGroupIdentifier) {
                sharedDefaults.set(data, forKey: WidgetSharedStorage.citiesKey)
            } else {
                log("Failed to open shared defaults for app group \(WidgetSharedStorage.appGroupIdentifier)")
            }
            #if canImport(WidgetKit)
            WidgetCenter.shared.reloadAllTimelines()
            #endif
        } catch {
            log("Failed to mirror cities to shared defaults. Error: \(error)")
        }
    }
}
