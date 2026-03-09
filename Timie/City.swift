import Foundation

struct CanonicalCity: Identifiable, Equatable, Hashable {
    let id: String
    let name: String
    let timeZoneID: String

    var timeZone: TimeZone {
        TimeZone(identifier: timeZoneID) ?? .current
    }

    init(name: String, timeZoneID: String) {
        self.id = timeZoneID
        self.name = name
        self.timeZoneID = timeZoneID
    }
}

struct City: Identifiable, Equatable {
    static let current = City(name: "Bangkok", timeZoneID: "Asia/Bangkok")

    let canonicalCity: CanonicalCity
    var customDisplayName: String?

    var id: String { canonicalCity.id }
    var name: String { canonicalCity.name }
    var timeZoneID: String { canonicalCity.timeZoneID }

    var displayName: String {
        let trimmedCustomName = customDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmedCustomName.isEmpty ? canonicalCity.name : trimmedCustomName
    }

    var timeZone: TimeZone {
        canonicalCity.timeZone
    }

    init(canonicalCity: CanonicalCity, customDisplayName: String? = nil) {
        self.canonicalCity = canonicalCity
        self.customDisplayName = customDisplayName
    }

    init(name: String, timeZoneID: String, customDisplayName: String? = nil) {
        self.init(
            canonicalCity: CanonicalCity(name: name, timeZoneID: timeZoneID),
            customDisplayName: customDisplayName
        )
    }

    // Backward-compatible alias for pre-refactor call sites.
    init(name: String, timeZoneID: String, customName: String?) {
        self.init(name: name, timeZoneID: timeZoneID, customDisplayName: customName)
    }

    // Backward-compatible alias for pre-refactor call sites.
    var customName: String? {
        get { customDisplayName }
        set { customDisplayName = newValue }
    }
}
