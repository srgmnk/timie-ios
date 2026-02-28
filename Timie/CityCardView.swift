import SwiftUI

struct CityCardView: View {
    let city: City
    let selectedInstant: Date
    let referenceTimeZone: TimeZone
    let isCurrent: Bool
    let cardBackgroundColor: Color

    private let titleColor = Color(red: 0xE8 / 255, green: 0x53 / 255, blue: 0x34 / 255)

    private var timeText: String {
        CityTimeFormatter.formatTime(selectedInstant, in: city.timeZone)
    }

    private var dateText: String {
        CityTimeFormatter.formatDate(selectedInstant, in: city.timeZone)
    }

    private var utcOffsetValueText: String {
        CityTimeFormatter.formatUTCOffsetValue(selectedInstant, in: city.timeZone)
    }

    private var centerBottomText: String {
        guard !isCurrent else { return "Current" }

        let cityOffsetSeconds = city.timeZone.secondsFromGMT(for: selectedInstant)
        let referenceOffsetSeconds = referenceTimeZone.secondsFromGMT(for: selectedInstant)
        let deltaSeconds = cityOffsetSeconds - referenceOffsetSeconds
        let sign = deltaSeconds >= 0 ? "+" : "−"
        let totalMinutes = abs(deltaSeconds / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if minutes == 0 {
            return "\(sign)\(hours)h from Current"
        }

        return String(format: "%@%d:%02d from Current", sign, hours, minutes)
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
                Text(city.name)
                    .font(.system(size: 14, weight: .semibold))
                    .tracking(-0.42)
                    .foregroundStyle(titleColor)
                    .padding(.top, 20)

                Text(timeText)
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundStyle(.black)
                    .padding(.top, 4)

                Spacer(minLength: 0)
            }

            VStack {
                Spacer()

                HStack(alignment: .center) {
                    HStack(spacing: 2) {
                        Image(systemName: dayNightSymbol)
                            .font(.system(size: 14, weight: .medium))
                        Text(dateText)
                            .font(.system(size: 14, weight: .medium))
                            .tracking(-0.42)
                    }
                    .foregroundStyle(.black.opacity(0.2))

                    Spacer()

                    HStack(spacing: 0) {
                        Text("UTC")
                            .font(.system(size: 14, weight: .medium))
                            .tracking(-0.42)
                            .foregroundStyle(.black.opacity(0.2))
                        Text(utcOffsetValueText)
                            .font(.system(size: 14, weight: .medium))
                            .tracking(-0.42)
                            .foregroundStyle(.black.opacity(0.5))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }

            VStack {
                Spacer()
                Text(centerBottomText)
                    .font(.system(size: 14, weight: .medium))
                    .tracking(-0.42)
                    .foregroundStyle(.black.opacity(0.2))
                    .padding(.bottom, 20)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 140)
        .background(cardBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}
