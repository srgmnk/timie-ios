import SwiftUI

struct CityCardView: View {
    @Environment(\.appTheme) private var theme
    let city: City
    let selectedInstant: Date
    let referenceTimeZone: TimeZone
    let isCurrent: Bool
    var isUserCurrentLocation: Bool = false
    var cityViewPreference: CityViewPreference = .basic
    let cardBackgroundColor: Color

    private var titleColor: Color { theme.accent }
    private var secondaryTextColor: Color { theme.textSecondary }
    private let basicMeridiemLabelXOffset: CGFloat = 76
    private let basicMeridiemLabelYOffset: CGFloat = 12
    private let compactMeridiemLabelXOffset: CGFloat = 52
    private let compactMeridiemLabelYOffset: CGFloat = 7

    private var timeComponents: CityTimeFormatter.TimeComponents {
        CityTimeFormatter.formatTimeComponents(selectedInstant, in: city.timeZone)
    }

    private var dateText: String {
        CityTimeFormatter.formatDate(selectedInstant, in: city.timeZone)
    }

    private var utcOffsetValueText: String {
        CityTimeFormatter.formatUTCOffsetValue(selectedInstant, in: city.timeZone)
    }

    private var shouldShowDSTTag: Bool {
        guard !isZeroOffsetReferenceCity else { return false }
        return city.timeZone.isDaylightSavingTime(for: selectedInstant)
    }

    private var isZeroOffsetReferenceCity: Bool {
        let canonicalID = city.id.lowercased()
        if canonicalID == "custom.utc" || canonicalID == "custom.gmt" {
            return true
        }

        let timeZoneID = city.timeZoneID.lowercased()
        return timeZoneID == "etc/utc" || timeZoneID == "utc" || timeZoneID == "gmt"
    }

    private var deltaDisplay: (isPositive: Bool, text: String)? {
        guard !isCurrent else { return nil }
        let cityOffsetSeconds = city.timeZone.secondsFromGMT(for: selectedInstant)
        let referenceOffsetSeconds = referenceTimeZone.secondsFromGMT(for: selectedInstant)
        let deltaSeconds = cityOffsetSeconds - referenceOffsetSeconds
        let isPositive = deltaSeconds >= 0
        let totalMinutes = abs(deltaSeconds / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if minutes == 0 {
            return (isPositive, "\(hours)h")
        }

        return (isPositive, String(format: "%d:%02d", hours, minutes))
    }

    private var deltaText: String {
        if isCurrent {
            return "Current"
        }
        return deltaDisplay?.text ?? "0h"
    }

    private var deltaSymbolName: String {
        guard let deltaDisplay else { return "" }
        return deltaDisplay.isPositive
            ? "plus.arrow.trianglehead.clockwise"
            : "minus.arrow.trianglehead.counterclockwise"
    }

    private var dayNightSymbol: String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = city.timeZone
        let hour = calendar.component(.hour, from: selectedInstant)
        return (8..<20).contains(hour) ? "sun.max.fill" : "moon.stars.fill"
    }

    private var cardHeight: CGFloat {
        cityViewPreference == .compact ? 88 : 140
    }

    var body: some View {
        Group {
            switch cityViewPreference {
            case .basic:
                basicLayout
            case .compact:
                compactLayout
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: cardHeight)
        .background(cardBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var basicLayout: some View {
        ZStack {
            VStack(spacing: 0) {
                cityTitle(fontSize: 14, locationSize: 12)
                    .padding(.top, 16)

                ZStack {
                    Text(timeComponents.numeric)
                        .font(.system(size: 48, weight: .medium))
                        .monospacedDigit()
                        .tracking(-1)
                        .foregroundStyle(theme.textPrimary)

                    if let meridiem = timeComponents.meridiem {
                        Text(meridiem)
                            .font(.system(size: 14, weight: .medium))
                            .tracking(-0.42)
                            .foregroundStyle(theme.textPrimary)
                            .offset(x: basicMeridiemLabelXOffset, y: basicMeridiemLabelYOffset)
                    }
                }
                .padding(.top, 4)
                .offset(y: 3)

                Spacer(minLength: 0)
            }

            VStack {
                Spacer()

                HStack {
                    basicDeltaView

                    Spacer(minLength: 0)

                    trailingTimezone
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }

            VStack {
                Spacer()
                HStack(spacing: 2) {
                    dayNightIcon(size: 14, weight: .medium)
                    Text(dateText)
                        .font(.system(size: 14, weight: .medium))
                        .tracking(-0.42)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .foregroundStyle(secondaryTextColor)
                .padding(.bottom, 16)
                .allowsHitTesting(false)
            }
        }
    }

    private var compactLayout: some View {
        ZStack {
            compactTimeView
                .offset(y: 12)

            VStack {
                HStack {
                    dayNightIcon(size: 14, weight: .medium)

                    Spacer(minLength: 0)

                    compactDeltaView
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                Spacer(minLength: 0)

                HStack(alignment: .center) {
                    Text(dateText)
                        .font(.system(size: 14, weight: .medium))
                        .tracking(-0.42)
                        .foregroundStyle(secondaryTextColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    Spacer(minLength: 0)

                    trailingTimezone
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }

            VStack(spacing: 0) {
                cityTitle(fontSize: 14, locationSize: 10)
                    .padding(.top, 14)

                Spacer(minLength: 0)
            }
        }
    }

    private var compactTimeView: some View {
        ZStack {
            Text(timeComponents.numeric)
                .font(.system(size: 32, weight: .medium))
                .monospacedDigit()
                .tracking(-0.64)
                .foregroundStyle(theme.textPrimary)

            if let meridiem = timeComponents.meridiem {
                Text(meridiem)
                    .font(.system(size: 12, weight: .medium))
                    .tracking(-0.24)
                    .foregroundStyle(theme.textPrimary)
                    .offset(x: compactMeridiemLabelXOffset, y: compactMeridiemLabelYOffset)
            }
        }
        .offset(y: 2)
    }

    private var basicDeltaView: some View {
        HStack(spacing: 2) {
            if isCurrent {
                Text(deltaText)
                    .font(.system(size: 14, weight: .regular))
                    .tracking(-0.42)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
            } else {
                Image(systemName: deltaSymbolName)
                    .font(.system(size: 12, weight: .regular))
                    .offset(y: -0.5)

                Text(deltaText)
                    .font(.system(size: 14, weight: .regular))
                    .tracking(-0.42)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
            }
        }
        .foregroundStyle(secondaryTextColor)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(deltaAccessibilityLabel)
    }

    private var compactDeltaView: some View {
        Group {
            if isCurrent {
                Text(deltaText)
                    .font(.system(size: 14, weight: .regular))
                    .tracking(-0.42)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
            } else {
                HStack(spacing: 2) {
                    Text(deltaText)
                        .font(.system(size: 14, weight: .regular))
                        .tracking(-0.42)
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)

                    Image(systemName: deltaSymbolName)
                        .font(.system(size: 12, weight: .regular))
                        .offset(y: -0.5)
                }
            }
        }
        .foregroundStyle(secondaryTextColor)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(deltaAccessibilityLabel)
    }

    private var trailingTimezone: some View {
        HStack(spacing: 4) {
            HStack(spacing: 0) {
                Text("UTC")
                    .font(.system(size: 14, weight: .regular))
                    .tracking(-0.42)
                    .foregroundStyle(secondaryTextColor)
                Text(utcOffsetValueText)
                    .font(.system(size: 14, weight: .regular))
                    .tracking(-0.42)
                    .foregroundStyle(secondaryTextColor)
            }

            if shouldShowDSTTag {
                Text("DST")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(cityViewPreference == .compact ? -0.2 : -0.9)
                    .foregroundStyle(theme.textSecondary)
                    .padding(.horizontal, 5)
                    .padding(.bottom, 0.5)
                    .frame(height: 17)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(theme.borderSubtle, lineWidth: 1)
                    )
            }
        }
    }

    private var deltaAccessibilityLabel: String {
        if isCurrent {
            return "Current"
        }

        let hoursText = deltaText.replacingOccurrences(of: ":", with: " hours ")
        return (deltaDisplay?.isPositive == true ? "plus " : "minus ") + hoursText
    }

    private func cityTitle(fontSize: CGFloat, locationSize: CGFloat) -> some View {
        HStack(spacing: 4) {
            if isUserCurrentLocation {
                Image(systemName: "location.fill")
                    .font(.system(size: locationSize, weight: .semibold))
                    .foregroundStyle(titleColor)
            }

            Text(city.displayName)
                .font(.system(size: fontSize, weight: .semibold))
                .tracking(-0.42)
                .foregroundStyle(titleColor)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
    }

    private func dayNightIcon(size: CGFloat, weight: Font.Weight) -> some View {
        Image(systemName: dayNightSymbol)
            .font(.system(size: size, weight: weight))
            .foregroundStyle(secondaryTextColor)
    }
}
