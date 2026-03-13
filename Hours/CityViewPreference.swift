import Foundation

enum CityViewPreference: String, CaseIterable, Codable {
    case basic
    case compact

    static let storageKey = "cityViewPreference"

    var displayTitle: String {
        switch self {
        case .basic:
            return "Basic"
        case .compact:
            return "Compact"
        }
    }

    static func from(rawValue: String) -> CityViewPreference {
        CityViewPreference(rawValue: rawValue) ?? .basic
    }
}
