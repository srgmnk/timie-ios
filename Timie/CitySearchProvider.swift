import Foundation
import MapKit

@MainActor
final class CitySearchProvider {
    static let shared = CitySearchProvider()

    private struct IndexedLocalItem {
        let item: CitySearchItem
        let order: Int
        let normalizedCity: String
        let normalizedCountry: String
        let normalizedAliases: [String]
        let normalizedTimeZone: String
    }

    private let indexedLocalItems: [IndexedLocalItem]
    private let cityCountryToTimeZone: [String: String]

    private let localResultLimit = 40
    private let mergedResultLimit = 60
    private let minimumGoodLocalResultCount = 5

    private init(bundle: Bundle = .main) {
        let localItems = Self.loadLocalItems(bundle: bundle)

        indexedLocalItems = localItems.enumerated().map { index, item in
            IndexedLocalItem(
                item: item,
                order: index,
                normalizedCity: Self.normalize(item.city),
                normalizedCountry: Self.normalize(item.country),
                normalizedAliases: item.aliases.map(Self.normalize),
                normalizedTimeZone: Self.normalize(item.timeZoneIdentifier)
            )
        }

        var lookup: [String: String] = [:]
        for indexed in indexedLocalItems {
            let key = Self.cityCountryKey(city: indexed.normalizedCity, country: indexed.normalizedCountry)
            lookup[key] = indexed.item.timeZoneIdentifier
        }
        cityCountryToTimeZone = lookup
    }

    func localResults(
        matching query: String,
        excluding existingTimeZoneIDs: Set<String>
    ) -> [CitySearchItem] {
        let normalizedQuery = Self.normalize(query)
        if normalizedQuery.isEmpty {
            return indexedLocalItems
                .filter { !existingTimeZoneIDs.contains($0.item.timeZoneIdentifier) }
                .prefix(localResultLimit)
                .map(\.item)
        }

        let ranked = indexedLocalItems.compactMap { indexed -> (rank: Int, order: Int, item: CitySearchItem)? in
            guard !existingTimeZoneIDs.contains(indexed.item.timeZoneIdentifier) else { return nil }
            guard let rank = Self.localRank(for: indexed, query: normalizedQuery) else { return nil }
            return (rank, indexed.order, indexed.item)
        }

        let sorted = ranked.sorted { lhs, rhs in
            if lhs.rank != rhs.rank { return lhs.rank < rhs.rank }
            if lhs.order != rhs.order { return lhs.order < rhs.order }
            return lhs.item.city.localizedCaseInsensitiveCompare(rhs.item.city) == .orderedAscending
        }

        return Self.deduplicatedByTimeZone(sorted.map(\.item))
            .prefix(localResultLimit)
            .map { $0 }
    }

    func shouldFetchFallback(for query: String, localResultCount: Int) -> Bool {
        let normalizedQuery = Self.normalize(query)
        guard normalizedQuery.count >= 2 else { return false }
        return localResultCount == 0 || localResultCount < minimumGoodLocalResultCount
    }

    func fallbackMergedResults(
        matching query: String,
        localResults: [CitySearchItem],
        excluding existingTimeZoneIDs: Set<String>
    ) async -> [CitySearchItem] {
        guard shouldFetchFallback(for: query, localResultCount: localResults.count) else {
            return localResults
        }

        let fallback = await mapKitFallbackResults(
            matching: query,
            excluding: existingTimeZoneIDs,
            localResults: localResults
        )

        return mergeResults(
            localResults: localResults,
            fallbackResults: fallback,
            excluding: existingTimeZoneIDs
        )
    }

    func canonicalItemForCurrentLocation(
        city: String,
        country: String,
        timeZoneIdentifier: String
    ) -> CitySearchItem? {
        let normalizedCity = Self.normalize(city)
        let normalizedCountry = Self.normalize(country)
        let normalizedTimeZone = Self.normalize(timeZoneIdentifier)

        if let exact = indexedLocalItems.first(where: {
            $0.normalizedCity == normalizedCity &&
            $0.normalizedCountry == normalizedCountry &&
            $0.normalizedTimeZone == normalizedTimeZone
        }) {
            return exact.item
        }

        if let cityAndCountry = indexedLocalItems.first(where: {
            $0.normalizedCity == normalizedCity &&
            $0.normalizedCountry == normalizedCountry
        }) {
            return cityAndCountry.item
        }

        if let timeZoneAndCountry = indexedLocalItems.first(where: {
            $0.normalizedTimeZone == normalizedTimeZone &&
            $0.normalizedCountry == normalizedCountry
        }) {
            return timeZoneAndCountry.item
        }

        if let timeZoneOnly = indexedLocalItems.first(where: {
            $0.normalizedTimeZone == normalizedTimeZone
        }) {
            return timeZoneOnly.item
        }

        return nil
    }

    private func mapKitFallbackResults(
        matching query: String,
        excluding existingTimeZoneIDs: Set<String>,
        localResults: [CitySearchItem]
    ) async -> [CitySearchItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = trimmed
        request.resultTypes = [.address]

        let response: MKLocalSearch.Response
        do {
            response = try await MKLocalSearch(request: request).start()
        } catch {
            return []
        }

        let normalizedQuery = Self.normalize(trimmed)
        var dedupeTimeZones = Set(localResults.map(\.timeZoneIdentifier))
        dedupeTimeZones.formUnion(existingTimeZoneIDs)
        var dedupeCityCountry = Set(localResults.map { Self.cityCountryKey(city: Self.normalize($0.city), country: Self.normalize($0.country)) })

        var candidates: [(rank: Int, item: CitySearchItem)] = []

        for mapItem in response.mapItems {
            guard CLLocationCoordinate2DIsValid(mapItem.location.coordinate) else { continue }

            let city = Self.cityName(from: mapItem)
            guard !city.isEmpty else { continue }

            let country = Self.countryName(from: mapItem)
            guard !country.isEmpty else { continue }

            var timeZoneID = mapItem.timeZone?.identifier
            if timeZoneID == nil {
                let key = Self.cityCountryKey(city: Self.normalize(city), country: Self.normalize(country))
                timeZoneID = cityCountryToTimeZone[key]
            }
            guard let timeZoneIdentifier = timeZoneID, !timeZoneIdentifier.isEmpty else { continue }

            guard !dedupeTimeZones.contains(timeZoneIdentifier) else { continue }

            let cityCountry = Self.cityCountryKey(city: Self.normalize(city), country: Self.normalize(country))
            guard !dedupeCityCountry.contains(cityCountry) else { continue }

            let item = CitySearchItem(
                id: "mapkit-\(Self.normalize(city))|\(Self.normalize(country))|\(timeZoneIdentifier)",
                city: city,
                country: country,
                timeZoneIdentifier: timeZoneIdentifier,
                aliases: []
            )

            let rank = Self.fallbackRank(city: Self.normalize(city), country: Self.normalize(country), query: normalizedQuery)
            candidates.append((rank, item))
            dedupeTimeZones.insert(timeZoneIdentifier)
            dedupeCityCountry.insert(cityCountry)
        }

        return candidates
            .sorted { lhs, rhs in
                if lhs.rank != rhs.rank { return lhs.rank < rhs.rank }
                let cityOrder = lhs.item.city.localizedCaseInsensitiveCompare(rhs.item.city)
                if cityOrder != .orderedSame { return cityOrder == .orderedAscending }
                return lhs.item.country.localizedCaseInsensitiveCompare(rhs.item.country) == .orderedAscending
            }
            .map(\.item)
    }

    private func mergeResults(
        localResults: [CitySearchItem],
        fallbackResults: [CitySearchItem],
        excluding existingTimeZoneIDs: Set<String>
    ) -> [CitySearchItem] {
        var merged: [CitySearchItem] = []
        var seenTimeZones = Set<String>()
        var seenCityCountry = Set<String>()

        func appendIfNeeded(_ item: CitySearchItem) {
            if existingTimeZoneIDs.contains(item.timeZoneIdentifier) { return }
            if seenTimeZones.contains(item.timeZoneIdentifier) { return }

            let cityCountry = Self.cityCountryKey(
                city: Self.normalize(item.city),
                country: Self.normalize(item.country)
            )
            if seenCityCountry.contains(cityCountry) { return }

            merged.append(item)
            seenTimeZones.insert(item.timeZoneIdentifier)
            seenCityCountry.insert(cityCountry)
        }

        for item in localResults {
            appendIfNeeded(item)
        }
        for item in fallbackResults {
            appendIfNeeded(item)
        }

        return Array(merged.prefix(mergedResultLimit))
    }

    private static func localRank(for indexed: IndexedLocalItem, query: String) -> Int? {
        if indexed.normalizedCity == query { return 0 }
        if indexed.normalizedCity.hasPrefix(query) { return 1 }
        if indexed.normalizedAliases.contains(where: { $0.hasPrefix(query) }) { return 2 }
        if indexed.normalizedCity.contains(query) { return 3 }
        if indexed.normalizedCountry.hasPrefix(query) { return 4 }
        if indexed.normalizedCountry.contains(query) { return 5 }
        if indexed.normalizedAliases.contains(where: { $0.contains(query) }) { return 6 }
        if indexed.normalizedTimeZone.contains(query) { return 7 }
        return nil
    }

    private static func fallbackRank(city: String, country: String, query: String) -> Int {
        if city == query { return 8 }
        if city.hasPrefix(query) { return 9 }
        if city.contains(query) { return 10 }
        if country.hasPrefix(query) { return 11 }
        if country.contains(query) { return 12 }
        return 13
    }

    private static func cityName(from mapItem: MKMapItem) -> String {
        let candidates: [String?] = [
            mapItem.addressRepresentations?.cityName,
            firstAddressComponent(from: mapItem.addressRepresentations?.cityWithContext),
            firstAddressComponent(from: mapItem.address?.shortAddress),
            firstAddressComponent(from: mapItem.address?.fullAddress)
        ]

        for candidate in candidates {
            let value = candidate?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !value.isEmpty else { continue }
            if value.contains(where: { $0.isNumber }) { continue }
            return value
        }

        return ""
    }

    private static func countryName(from mapItem: MKMapItem) -> String {
        let candidates: [String?] = [
            mapItem.addressRepresentations?.regionName,
            lastAddressComponent(from: mapItem.addressRepresentations?.cityWithContext(.full)),
            lastAddressComponent(from: mapItem.address?.fullAddress)
        ]

        for candidate in candidates {
            let value = candidate?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !value.isEmpty else { continue }
            if value.contains(where: { $0.isNumber }) { continue }
            return value
        }

        return ""
    }

    private static func firstAddressComponent(from value: String?) -> String {
        guard let value else { return "" }

        return value
            .replacingOccurrences(of: "\n", with: ",")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty }) ?? ""
    }

    private static func lastAddressComponent(from value: String?) -> String {
        guard let value else { return "" }

        return value
            .replacingOccurrences(of: "\n", with: ",")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .last(where: { !$0.isEmpty }) ?? ""
    }

    private static func normalize(_ input: String) -> String {
        input
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private static func cityCountryKey(city: String, country: String) -> String {
        "\(city)|\(country)"
    }

    private static func deduplicatedByTimeZone(_ items: [CitySearchItem]) -> [CitySearchItem] {
        var seen = Set<String>()
        var deduplicated: [CitySearchItem] = []

        for item in items {
            guard !seen.contains(item.timeZoneIdentifier) else { continue }
            seen.insert(item.timeZoneIdentifier)
            deduplicated.append(item)
        }

        return deduplicated
    }

    private static func loadLocalItems(bundle: Bundle) -> [CitySearchItem] {
        let candidateURLs: [URL?] = [
            bundle.url(forResource: "cities", withExtension: "json", subdirectory: "Resources"),
            bundle.url(forResource: "cities", withExtension: "json")
        ]

        let decoder = JSONDecoder()

        for candidateURL in candidateURLs {
            guard let url = candidateURL else { continue }
            guard let data = try? Data(contentsOf: url) else { continue }
            guard let decoded = try? decoder.decode([CitySearchItem].self, from: data) else { continue }
            if !decoded.isEmpty {
                return decoded
            }
        }

        return fallbackLocalItems
    }

    private static let fallbackLocalItems: [CitySearchItem] = [
        CitySearchItem(
            id: "fallback-bangkok",
            city: "Bangkok",
            country: "Thailand",
            timeZoneIdentifier: "Asia/Bangkok",
            aliases: ["bkk", "krung thep"]
        ),
        CitySearchItem(
            id: "fallback-perm",
            city: "Perm",
            country: "Russia",
            timeZoneIdentifier: "Asia/Yekaterinburg",
            aliases: ["perm russia", "perm krai"]
        ),
        CitySearchItem(
            id: "fallback-london",
            city: "London",
            country: "United Kingdom",
            timeZoneIdentifier: "Europe/London",
            aliases: ["ldn"]
        ),
        CitySearchItem(
            id: "fallback-new-york",
            city: "New York",
            country: "United States",
            timeZoneIdentifier: "America/New_York",
            aliases: ["nyc", "new york city"]
        ),
        CitySearchItem(
            id: "fallback-tokyo",
            city: "Tokyo",
            country: "Japan",
            timeZoneIdentifier: "Asia/Tokyo",
            aliases: []
        ),
        CitySearchItem(
            id: "fallback-sydney",
            city: "Sydney",
            country: "Australia",
            timeZoneIdentifier: "Australia/Sydney",
            aliases: ["syd"]
        )
    ]
}
