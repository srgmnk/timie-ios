import Foundation
import SwiftUI
import Combine

@MainActor
final class TimeDialViewModel: ObservableObject {
    enum Mode {
        case now
        case future
        case past
    }

    @Published private(set) var now = Date() {
        didSet { recomputeSelectedInstant() }
    }
    @Published var baseTime = Date() {
        didSet { recomputeSelectedInstant() }
    }
    @Published private(set) var selectedInstant = Date()
    @Published var deltaMinutes = 0 {
        didSet { recomputeSelectedInstant() }
    }
    @Published var isInteracting = false {
        didSet { recomputeSelectedInstant() }
    }
    @Published var rotationDegrees = 0.0
    @Published var dialSteps = 0 {
        didSet { syncDeltaFromDialSteps() }
    }
    @Published var resetSignal = 0

    private var tickerTask: Task<Void, Never>?
    private var inertiaTask: Task<Void, Never>?
    private let minutesPerRevolution = 1_440
    private let minutesPerTick = 5
    private let rotationToMinutesSign = -1.0
    private let calendar = Calendar.current
    private var stepAngleDegrees: Double {
        360.0 / (Double(minutesPerRevolution) / Double(minutesPerTick))
    }

    var mode: Mode {
        if deltaMinutes == 0 { return .now }
        return deltaMinutes > 0 ? .future : .past
    }

    init() {
        selectedInstant = now
        startTicker()
    }

    deinit {
        tickerTask?.cancel()
        inertiaTask?.cancel()
    }

    func beginInteractionIfNeeded() {
        guard !isInteracting else { return }
        baseTime = now
        isInteracting = true
    }

    func beginDialDrag() {
        inertiaTask?.cancel()
        beginInteractionIfNeeded()
    }

    func updateDialRotation(_ degrees: Double) {
        applyRotation(degrees, updateStep: true)
    }

    func endDialDrag(currentRotation: Double, predictedRotation: Double) {
        isInteracting = false
        startInertia(from: currentRotation, predicted: predictedRotation)
    }

    func resetToNow() {
        inertiaTask?.cancel()
        dialSteps = 0
        rotationDegrees = 0
        deltaMinutes = 0
        isInteracting = false
        baseTime = now
        resetSignal &+= 1
    }

    private func syncDeltaFromDialSteps() {
        if dialSteps == 0 {
            deltaMinutes = 0
        } else {
            deltaMinutes = roundedBaseOffsetMinutes(from: baseTime) + (dialSteps * minutesPerTick)
        }
        if deltaMinutes == 0 {
            isInteracting = false
        }
    }

    private func recomputeSelectedInstant() {
        if deltaMinutes == 0, !isInteracting {
            selectedInstant = now
        } else {
            let steppedBaseTime = dialSteps == 0 ? baseTime : roundedBaseTime(from: baseTime)
            selectedInstant = steppedBaseTime.addingTimeInterval(TimeInterval(dialSteps * minutesPerTick * 60))
        }
    }

    private func applyRotation(_ degrees: Double, updateStep: Bool) {
        rotationDegrees = degrees
        guard updateStep else { return }
        let minutes = rotationToMinutesSign * (degrees / 360.0) * Double(minutesPerRevolution)
        let snappedMinutes = (minutes / Double(minutesPerTick)).rounded() * Double(minutesPerTick)
        dialSteps = Int(snappedMinutes / Double(minutesPerTick))
    }

    private func startInertia(from current: Double, predicted: Double) {
        inertiaTask?.cancel()

        let predictionHorizon = 0.20
        let maxVelocity = 720.0
        let damping = 7.5
        let thresholdVelocity = 10.0
        let maxDistance = 180.0

        let rawVelocity = (predicted - current) / predictionHorizon
        var velocity = min(max(rawVelocity, -maxVelocity), maxVelocity)
        if abs(velocity) < 15 {
            snapToNearestStep()
            return
        }

        inertiaTask = Task { [weak self] in
            guard let self else { return }
            var angle = current
            var travelled = 0.0
            let dt = 1.0 / 60.0
            let decay = exp(-damping * dt)

            while !Task.isCancelled, abs(velocity) > thresholdVelocity, abs(travelled) < maxDistance {
                let delta = velocity * dt
                angle += delta
                travelled += delta
                self.applyRotation(angle, updateStep: true)
                velocity *= decay
                try? await Task.sleep(nanoseconds: 16_666_667)
            }

            self.snapToNearestStep()
        }
    }

    private func snapToNearestStep() {
        let targetMinutes = rotationToMinutesSign * (rotationDegrees / 360.0) * Double(minutesPerRevolution)
        let snappedMinutes = (targetMinutes / Double(minutesPerTick)).rounded() * Double(minutesPerTick)
        let targetStep = Int(snappedMinutes / Double(minutesPerTick))
        let targetRotation = (Double(targetStep) * stepAngleDegrees) / rotationToMinutesSign
        dialSteps = targetStep
        withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
            applyRotation(targetRotation, updateStep: false)
        }
    }

    private func startTicker() {
        tickerTask = Task {
            while !Task.isCancelled {
                now = Date()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private func roundedBaseTime(from date: Date) -> Date {
        let minuteAlignedDate = minuteAligned(date)
        let minute = calendar.component(.minute, from: minuteAlignedDate)
        let roundedMinute = Int((Double(minute) / Double(minutesPerTick)).rounded()) * minutesPerTick
        let minuteOffset = roundedMinute - minute
        return calendar.date(byAdding: .minute, value: minuteOffset, to: minuteAlignedDate) ?? minuteAlignedDate
    }

    private func roundedBaseOffsetMinutes(from date: Date) -> Int {
        let minuteAlignedDate = minuteAligned(date)
        let roundedDate = roundedBaseTime(from: date)
        return calendar.dateComponents([.minute], from: minuteAlignedDate, to: roundedDate).minute ?? 0
    }

    private func minuteAligned(_ date: Date) -> Date {
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return calendar.date(from: components) ?? date
    }
}
