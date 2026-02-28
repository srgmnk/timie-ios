import SwiftUI
import UIKit
#if DEBUG
import QuartzCore
#endif

#if DEBUG
private final class ThrottledLogger {
    private var last: CFTimeInterval = 0
    let minInterval: CFTimeInterval

    init(minInterval: CFTimeInterval = 0.1) {
        self.minInterval = minInterval
    }

    func log(_ message: @autoclosure () -> String) {
        let now = CACurrentMediaTime()
        guard now - last >= minInterval else { return }
        last = now
        print(message())
    }
}
#endif

struct TimeDialScreen: View {
    @StateObject private var viewModel = TimeDialViewModel()
    @State private var lastSnappedOffsetSteps = 0

    private let dialSize: CGFloat = 512
    private let dialCenterYOffset: CGFloat = 125
    private let dialOverlayHeight: CGFloat = 260
    private let smallTickHaptics = UIImpactFeedbackGenerator(style: .light)
    private let bigTickHaptics = UIImpactFeedbackGenerator(style: .heavy)
    private let zeroTickHaptics = UINotificationFeedbackGenerator()
    private let resetNotificationHaptics = UINotificationFeedbackGenerator()
    #if DEBUG
    private static let dialLog = ThrottledLogger(minInterval: 0.15)
    #endif

    private var hapticsEnabled: Bool {
        #if targetEnvironment(simulator)
        false
        #else
        true
        #endif
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                Color(red: 238.0 / 255.0, green: 238.0 / 255.0, blue: 238.0 / 255.0)
                    .ignoresSafeArea()

                CityCardView(
                    cityName: viewModel.currentCity.name,
                    selectedInstant: viewModel.selectedInstant,
                    timeZoneID: viewModel.currentCity.timeZoneID,
                    cardBackgroundColor: Color(red: 0xF7 / 255, green: 0xF7 / 255, blue: 0xF7 / 255)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

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
                            prepareDialHaptics()
                            debugLog("[DIAL] drag begin")
                        },
                        onDragChanged: { rotation in
                            viewModel.updateDialRotation(rotation)
                        },
                        onDragEnded: { currentRotation, predictedRotation in
                            viewModel.endDialDrag(currentRotation: currentRotation, predictedRotation: predictedRotation)
                            debugLog(
                                "[DIAL] drag end current=\(String(format: "%.2f", currentRotation)) " +
                                "predicted=\(String(format: "%.2f", predictedRotation))"
                            )
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
                prepareDialHaptics()
                resetNotificationHaptics.prepare()
                lastSnappedOffsetSteps = viewModel.dialSteps
            }
            .onChange(of: viewModel.dialSteps) { _, newStep in
                guard newStep != lastSnappedOffsetSteps else { return }
                let tickType: String
                if newStep == 0 {
                    tickType = "zero"
                } else if abs(newStep).isMultiple(of: 6) {
                    tickType = "big"
                } else {
                    tickType = "small"
                }
                debugLog(
                    "[DIAL] snappedStep \(lastSnappedOffsetSteps) -> \(newStep) " +
                    "kind=\(tickType)"
                )
                fireHapticForSnappedStep(newStep)
                lastSnappedOffsetSteps = newStep
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

    private func fireHapticForSnappedStep(_ offsetSteps: Int) {
        guard hapticsEnabled else { return }

        if offsetSteps == 0 {
            zeroTickHaptics.notificationOccurred(.success)
            zeroTickHaptics.prepare()
            return
        }

        if abs(offsetSteps).isMultiple(of: 6) {
            bigTickHaptics.impactOccurred()
            bigTickHaptics.prepare()
            return
        }

        smallTickHaptics.impactOccurred()
        smallTickHaptics.prepare()
    }

    private func prepareDialHaptics() {
        guard hapticsEnabled else { return }
        smallTickHaptics.prepare()
        bigTickHaptics.prepare()
        zeroTickHaptics.prepare()
    }

    private func debugLog(_ message: @autoclosure () -> String) {
        #if DEBUG
        Self.dialLog.log(message())
        #endif
    }
}
