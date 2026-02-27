import SwiftUI
import UIKit

struct TimeDialScreen: View {
    @StateObject private var viewModel = TimeDialViewModel()
    @State private var lastHapticStep = 0
    @State private var lastHapticTime = Date.distantPast

    private let dialSize: CGFloat = 512
    private let dialCenterYOffset: CGFloat = 125
    private let dialOverlayHeight: CGFloat = 260
    private let minorHaptics = UIImpactFeedbackGenerator(style: .medium)
    private let majorHaptics = UIImpactFeedbackGenerator(style: .heavy)
    private let resetNotificationHaptics = UINotificationFeedbackGenerator()
    private let reorderNotificationHaptics = UINotificationFeedbackGenerator()
    private let maxHapticsPerSecond = 20.0

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                Color(red: 238.0 / 255.0, green: 238.0 / 255.0, blue: 238.0 / 255.0)
                    .ignoresSafeArea()

                CityReorderListView(
                    rows: cityRows,
                    onReorderStart: handleReorderStart,
                    onMove: handleReorderMove,
                    onDelete: handleDelete
                )

                ProgressiveBottomBlurOverlay(height: 180)
                    .allowsHitTesting(false)

                ZStack(alignment: .bottom) {
                    TimeDialView(
                        diameter: dialSize,
                        rotationDegrees: viewModel.rotationDegrees,
                        stepIndex: viewModel.dialSteps,
                        resetSignal: viewModel.resetSignal,
                        onDragBegan: {
                            viewModel.beginDialDrag()
                        },
                        onDragChanged: { rotation in
                            viewModel.updateDialRotation(rotation)
                        },
                        onDragEnded: { currentRotation, predictedRotation in
                            viewModel.endDialDrag(currentRotation: currentRotation, predictedRotation: predictedRotation)
                        }
                    )
                    .position(x: geo.size.width / 2, y: dialOverlayHeight + dialCenterYOffset)
                    .allowsHitTesting(true)

                    DeltaPillView(
                        mode: pillMode,
                        deltaText: absDeltaString,
                        onDoubleTapReset: resetToNow
                    )
                    .padding(.bottom, 32)
                    .allowsHitTesting(true)
                }
                .frame(maxWidth: .infinity)
                .frame(height: dialOverlayHeight + geo.safeAreaInsets.bottom, alignment: .bottom)
                .padding(.bottom, geo.safeAreaInsets.bottom)
                .allowsHitTesting(true)
            }
            .onAppear {
                minorHaptics.prepare()
                majorHaptics.prepare()
                resetNotificationHaptics.prepare()
                reorderNotificationHaptics.prepare()
                lastHapticStep = viewModel.dialSteps
            }
            .onChange(of: viewModel.dialSteps) { _, newStep in
                guard newStep != lastHapticStep else { return }
                let now = Date()
                let minInterval = 1.0 / maxHapticsPerSecond
                guard now.timeIntervalSince(lastHapticTime) >= minInterval else {
                    lastHapticStep = newStep
                    return
                }

                let absoluteStep = abs(newStep)
                let isMajorTick = absoluteStep != 0 && absoluteStep.isMultiple(of: 6)
                if isMajorTick {
                    majorHaptics.impactOccurred()
                } else {
                    minorHaptics.impactOccurred()
                }

                lastHapticStep = newStep
                lastHapticTime = now
                minorHaptics.prepare()
                majorHaptics.prepare()
            }
        }
        .ignoresSafeArea()
    }

    private var absDeltaString: String {
        let minutes = abs(viewModel.deltaMinutes)
        let hours = minutes / 60
        let mins = minutes % 60
        return "\(hours):" + String(format: "%02d", mins)
    }

    private var pillMode: DeltaPillView.PillMode {
        switch viewModel.mode {
        case .now: return .now
        case .future: return .future
        case .past: return .past
        }
    }

    private func resetToNow() {
        withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
            viewModel.resetToNow()
        }
        resetNotificationHaptics.notificationOccurred(.success)
        resetNotificationHaptics.prepare()
    }

    private func dayNightSymbol(for city: City, at instant: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = city.timeZone
        let hour = calendar.component(.hour, from: instant)
        return (8..<20).contains(hour) ? "sun.max.fill" : "moon.stars.fill"
    }

    private func centerBottomText(for city: City, at instant: Date) -> String {
        viewModel.centerBottomText(for: city, at: instant)
    }

    private var cityRows: [CityListRow] {
        let instant = viewModel.selectedInstant
        return viewModel.cities.map { city in
            CityListRow(
                id: city.id,
                cityName: city.name,
                timeText: CityTimeFormatter.formatTime(instant, in: city.timeZone),
                dayNightSymbol: dayNightSymbol(for: city, at: instant),
                dateText: CityTimeFormatter.formatDate(instant, in: city.timeZone),
                centerBottomText: centerBottomText(for: city, at: instant),
                utcOffsetValueText: CityTimeFormatter.formatUTCOffsetValue(instant, in: city.timeZone),
                isCurrent: viewModel.isCurrentCity(city)
            )
        }
    }

    private func handleReorderStart(_ cityID: String) {
        let cityName = viewModel.cities.first(where: { $0.id == cityID })?.name ?? cityID
        logReorder("start reorder cityID=\(cityID) city=\(cityName)")
        minorHaptics.impactOccurred()
        minorHaptics.prepare()
    }

    private func handleReorderMove(from sourceIndex: Int, to destinationIndex: Int) {
        let oldCurrent = viewModel.currentCityID
        logReorder("onMove from=\(sourceIndex) to=\(destinationIndex)")
        viewModel.moveCity(from: sourceIndex, to: destinationIndex)

        let top3 = viewModel.cities.prefix(3).map { "\($0.id)|\($0.name)" }.joined(separator: ", ")
        logReorder("final top3=[\(top3)]")

        if oldCurrent != viewModel.currentCityID {
            logReorder("current changed old=\(oldCurrent) new=\(viewModel.currentCityID)")
            reorderNotificationHaptics.notificationOccurred(.success)
            reorderNotificationHaptics.prepare()
        }
    }

    private func handleDelete(_ cityID: String) {
        viewModel.deleteCity(id: cityID)
    }

    private func logReorder(_ message: String) {
        print("[REORDER] \(message)")
    }
}
