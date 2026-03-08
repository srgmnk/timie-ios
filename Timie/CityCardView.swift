import SwiftUI

struct CityCardView: View {
    let city: City
    let selectedInstant: Date
    let referenceTimeZone: TimeZone
    let isCurrent: Bool
    var isUserCurrentLocation: Bool = false
    let cardBackgroundColor: Color

    private let titleColor = Color(red: 0xE8 / 255, green: 0x53 / 255, blue: 0x34 / 255)
    private let secondaryTextColor = Color.black.opacity(0.2)

    private var timeText: String {
        CityTimeFormatter.formatTime(selectedInstant, in: city.timeZone)
    }

    private var dateText: String {
        CityTimeFormatter.formatDate(selectedInstant, in: city.timeZone)
    }

    private var utcOffsetValueText: String {
        CityTimeFormatter.formatUTCOffsetValue(selectedInstant, in: city.timeZone)
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

    private var centerBottomText: String {
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

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                HStack(spacing: 4) {
                    if isUserCurrentLocation {
                        Image(systemName: "location.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(titleColor)
                    }

                    Text(city.displayName)
                        .font(.system(size: 14, weight: .semibold))
                        .tracking(-0.42)
                        .foregroundStyle(titleColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .padding(.top, 16)

                Text(timeText)
                    .font(.system(size: 48, weight: .medium))
                    .monospacedDigit()
                    .tracking(-1)
                    .foregroundStyle(.black)
                    .padding(.top, 4)
                    .offset(y: 3)

                Spacer(minLength: 0)
            }

            VStack {
                Spacer()

                HStack {
                    HStack(spacing: 2) {
                        if isCurrent {
                            Text(centerBottomText)
                                .font(.system(size: 14, weight: .regular))
                                .tracking(-0.42)
                                .lineLimit(1)
                                .minimumScaleFactor(0.9)
                        } else {
                            Image(systemName: deltaSymbolName)
                                .font(.system(size: 12, weight: .regular))
                                .offset(y: -0.5)
                            Text(centerBottomText)
                                .font(.system(size: 14, weight: .regular))
                                .tracking(-0.42)
                                .lineLimit(1)
                                .minimumScaleFactor(0.9)
                        }
                    }
                    .foregroundStyle(secondaryTextColor)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(
                        isCurrent
                            ? "Current"
                            : ((deltaDisplay?.isPositive == true ? "plus " : "minus ") + centerBottomText.replacingOccurrences(of: ":", with: " hours "))
                    )

                    Spacer(minLength: 0)

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
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }

            VStack {
                Spacer()
                HStack(spacing: 2) {
                    Image(systemName: dayNightSymbol)
                        .font(.system(size: 14, weight: .medium))
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
        .frame(maxWidth: .infinity)
        .frame(height: 140)
        .background(cardBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}
