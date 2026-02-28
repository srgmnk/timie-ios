import Foundation

struct City: Identifiable, Equatable {
    static let current = City(name: "Bangkok", timeZoneID: "Asia/Bangkok")

    static let initialList: [City] = [
        .current,
        City(name: "Tokyo", timeZoneID: "Asia/Tokyo"),
        City(name: "Sydney", timeZoneID: "Australia/Sydney"),
        City(name: "Dubai", timeZoneID: "Asia/Dubai"),
        City(name: "London", timeZoneID: "Europe/London"),
        City(name: "New York", timeZoneID: "America/New_York"),
        City(name: "Los Angeles", timeZoneID: "America/Los_Angeles")
    ]

    let id: String
    let name: String
    let timeZoneID: String

    var timeZone: TimeZone {
        TimeZone(identifier: timeZoneID) ?? .current
    }

    init(name: String, timeZoneID: String) {
        self.name = name
        self.timeZoneID = timeZoneID
        self.id = timeZoneID
    }
}
