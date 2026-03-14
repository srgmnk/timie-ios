import SwiftUI
import WidgetKit

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> HoursWidgetEntry {
        HoursWidgetEntry.placeholder(date: .now)
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> HoursWidgetEntry {
        entry(for: configuration, date: .now)
    }

    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<HoursWidgetEntry> {
        let calendar = Calendar.current
        let now = Date()

        let minuteStart = calendar.date(
            from: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: now)
        ) ?? now

        var entries: [HoursWidgetEntry] = []

        for minuteOffset in 0..<720 {
            let date = calendar.date(byAdding: .minute, value: minuteOffset, to: minuteStart) ?? minuteStart
            entries.append(entry(for: configuration, date: date))
        }

        return Timeline(entries: entries, policy: .atEnd)
    }

    private func entry(for configuration: ConfigurationAppIntent, date: Date) -> HoursWidgetEntry {
        let selectedCity = HoursWidgetCityReader.city(matching: configuration.city?.id)
        return HoursWidgetEntry(date: date, selectedCity: selectedCity)
    }
}

struct HoursWidgetEntry: TimelineEntry {
    let date: Date
    let selectedCity: HoursWidgetCityRecord?

    static func placeholder(date: Date) -> HoursWidgetEntry {
        HoursWidgetEntry(
            date: date,
            selectedCity: HoursWidgetCityRecord(
                id: "placeholder",
                canonicalName: "Bangkok",
                customDisplayName: nil,
                timeZoneIdentifier: "Asia/Bangkok"
            )
        )
    }
}

struct HoursWidgetEntryView: View {
    var entry: Provider.Entry

    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    var body: some View {
        ZStack {
            if let city = entry.selectedCity {
                cityContent(for: city)
            } else {
                placeholderContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(.clear, for: .widget)
    }

    private func cityContent(for city: HoursWidgetCityRecord) -> some View {
        VStack(spacing: 0) {
            Image(systemName: isDay(for: city, at: entry.date) ? "sun.max.fill" : "moon.fill")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.42))
                .padding(.bottom, 1)

            Text(formattedTime(for: city, at: entry.date))
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.68)
                .foregroundStyle(.white)
                .padding(.bottom, -1)

            Text(cityAbbreviation(for: city))
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.42))
                .lineLimit(1)
                .tracking(-0.2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .widgetAccentable()
    }

    private var placeholderContent: some View {
        VStack(spacing: 0) {
            Image(systemName: "clock")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.42))
                .padding(.bottom, 1)

            Text("--:--")
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.68)
                .foregroundStyle(.white)
                .padding(.bottom, -1)

            Text("ADD")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.42))
                .lineLimit(1)
                .tracking(-0.2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private func formattedTime(for city: HoursWidgetCityRecord, at date: Date) -> String {
        timeFormatter.timeZone = city.timeZone
        return timeFormatter.string(from: date)
    }

    private func isDay(for city: HoursWidgetCityRecord, at date: Date) -> Bool {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = city.timeZone
        let hour = calendar.component(.hour, from: date)
        return (6..<18).contains(hour)
    }

    private func cityAbbreviation(for city: HoursWidgetCityRecord) -> String {
        Self.cityAbbreviation(from: city.visibleName)
    }

    static func cityAbbreviation(from rawName: String) -> String {
        let trimmedName = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return "---" }

        let letters = trimmedName.filter(\.isLetter)
        if !letters.isEmpty {
            let prefix = String(letters.prefix(3))
            return prefix.lowercased().capitalized
        }

        let fallback = String(trimmedName.prefix(3))
        return fallback.lowercased().capitalized
    }
}

struct HoursWidget: Widget {
    let kind: String = "HoursWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()) { entry in
            HoursWidgetEntryView(entry: entry)
        }
        .supportedFamilies([.accessoryCircular])
        .configurationDisplayName("Hours")
        .description("Shows the local time for a saved city.")
    }
}
