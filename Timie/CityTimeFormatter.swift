import Foundation

enum CityTimeFormatter {
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "d MMM, EEE"
        return formatter
    }()

    static func formatTime(_ instant: Date, in timeZone: TimeZone) -> String {
        timeFormatter.timeZone = timeZone
        return timeFormatter.string(from: instant)
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
}
