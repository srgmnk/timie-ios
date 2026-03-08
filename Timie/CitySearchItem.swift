import Foundation

struct CitySearchItem: Identifiable, Codable, Hashable {
    let id: String
    let city: String
    let country: String
    let timeZoneIdentifier: String
    let aliases: [String]

    var asCity: City {
        City(canonicalCity: CanonicalCity(name: city, timeZoneID: timeZoneIdentifier))
    }

    func utcOffsetText(referenceDate: Date = Date()) -> String {
        guard let timeZone = TimeZone(identifier: timeZoneIdentifier) else {
            return "UTC"
        }
        return CityTimeFormatter.formatUTCOffset(referenceDate, in: timeZone)
    }

    func rowText(referenceDate: Date = Date()) -> String {
        "\(city), \(country), \(utcOffsetText(referenceDate: referenceDate))"
    }
}
