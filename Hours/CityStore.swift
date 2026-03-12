import Foundation
import SwiftUI
import Combine

@MainActor
final class CityStore: ObservableObject {
    @Published var cities: [City] = [] {
        didSet {
            log(
                "[EMPTYBUG] cities didSet oldCount=\(oldValue.count) newCount=\(cities.count) " +
                "isLoading=\(isLoading) main=\(Thread.isMainThread)"
            )
            guard !isLoading else { return }
            save()
        }
    }

    private let fileManager: FileManager
    private let citiesFileURL: URL
    private var isLoading = false
    private var debugCancellables: Set<AnyCancellable> = []

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        do {
            citiesFileURL = try Self.makeCitiesFileURL(fileManager: fileManager)
        } catch {
            let fallback = fileManager.temporaryDirectory.appendingPathComponent("cities.json", isDirectory: false)
            citiesFileURL = fallback
            log("Failed to resolve Application Support URL. Using fallback \(fallback.path). Error: \(error)")
        }
        setupDebugObservation()
        load()
    }

    func load() {
        log("[EMPTYBUG] load start path=\(citiesFileURL.path) main=\(Thread.isMainThread)")
        isLoading = true
        defer { isLoading = false }

        do {
            try ensureParentDirectoryExists()
            guard fileManager.fileExists(atPath: citiesFileURL.path) else {
                log("[EMPTYBUG] load file missing; initializing empty cities")
                cities = []
                return
            }
            let data = try Data(contentsOf: citiesFileURL)
            let decoded = try JSONDecoder().decode([City].self, from: data)
            log("[EMPTYBUG] load decoded count=\(decoded.count)")
            let migration = migrateCanonicalIdentitiesIfNeeded(decoded)
            cities = migration.cities
            log("[EMPTYBUG] load applied cities count=\(cities.count) migrated=\(migration.didMigrate)")
            if migration.didMigrate {
                save()
            }
        } catch {
            log("Failed to load cities from \(citiesFileURL.path). Error: \(error)")
            log("[EMPTYBUG] load failed; resetting to empty")
            cities = []
        }
    }

    func save() {
        log("[EMPTYBUG] save start count=\(cities.count) path=\(citiesFileURL.path) main=\(Thread.isMainThread)")
        do {
            try ensureParentDirectoryExists()
            let encoder = JSONEncoder()
            #if DEBUG
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            #endif
            let data = try encoder.encode(cities)
            try data.write(to: citiesFileURL, options: [.atomic])
            log("[EMPTYBUG] save success count=\(cities.count)")
        } catch {
            log("Failed to save cities to \(citiesFileURL.path). Error: \(error)")
            log("[EMPTYBUG] save failed count=\(cities.count)")
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

    private func setupDebugObservation() {
        #if DEBUG
        objectWillChange
            .sink { [weak self] in
                guard let self else { return }
                self.log(
                    "[EMPTYBUG] objectWillChange emitted currentCount=\(self.cities.count) " +
                    "isLoading=\(self.isLoading) main=\(Thread.isMainThread)"
                )
            }
            .store(in: &debugCancellables)
        #endif
    }

    private func log(_ message: String) {
        #if DEBUG
        print("[CityStore] \(message)")
        #endif
    }
}
