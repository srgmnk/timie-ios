import Foundation

enum CityTimeFormatter {
    struct TimeComponents {
        let numeric: String
        let meridiem: String?
    }

    private static let timeFormatter: DateFormatter = {
        DateFormatter()
    }()

    private static let meridiemFormatter: DateFormatter = {
        DateFormatter()
    }()

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "d MMM, EEE"
        return formatter
    }()

    static func formatTime(_ instant: Date, in timeZone: TimeZone) -> String {
        let components = formatTimeComponents(instant, in: timeZone)
        if let meridiem = components.meridiem {
            return "\(components.numeric) \(meridiem)"
        }
        return components.numeric
    }

    static func formatTimeComponents(_ instant: Date, in timeZone: TimeZone) -> TimeComponents {
        let locale = Locale.autoupdatingCurrent
        let uses12HourClock = uses12HourClock(for: locale)
        let resolvedFormat = uses12HourClock ? "hh:mm" : "HH:mm"

        timeFormatter.locale = locale
        timeFormatter.dateFormat = resolvedFormat
        timeFormatter.timeZone = timeZone
        let numeric = timeFormatter.string(from: instant)

        guard uses12HourClock else {
            return TimeComponents(numeric: numeric, meridiem: nil)
        }

        meridiemFormatter.locale = locale
        meridiemFormatter.dateFormat = "a"
        meridiemFormatter.timeZone = timeZone
        let meridiem = meridiemFormatter.string(from: instant).uppercased(with: locale)
        return TimeComponents(numeric: numeric, meridiem: meridiem)
    }

    static func formatDate(_ instant: Date, in timeZone: TimeZone) -> String {
        dateFormatter.timeZone = timeZone
        return dateFormatter.string(from: instant)
    }

    static func formatUTCOffset(_ instant: Date, in timeZone: TimeZone) -> String {
        let seconds = timeZone.secondsFromGMT(for: instant)
        let sign = seconds >= 0 ? "+" : "−"
        let totalMinutes = abs(seconds / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if minutes == 0 {
            return "UTC\(sign)\(hours)"
        }
        return String(format: "UTC%@%d:%02d", sign, hours, minutes)
    }

    static func formatUTCOffsetValue(_ instant: Date, in timeZone: TimeZone) -> String {
        let full = formatUTCOffset(instant, in: timeZone)
        return full.replacingOccurrences(of: "UTC", with: "")
    }

    private static func uses12HourClock(for locale: Locale) -> Bool {
        let hourTemplate = DateFormatter.dateFormat(
            fromTemplate: "j",
            options: 0,
            locale: locale
        ) ?? ""
        return hourTemplate.contains("a")
    }
}
