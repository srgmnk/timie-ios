import Foundation
import Combine
import SwiftUI

@MainActor
final class TimeDialViewModel: ObservableObject {
    enum Mode {
        case now
        case future
        case past
    }

    @Published private(set) var now = Date()
    @Published var baseTime = Date()
    @Published var cities: [City] = City.defaults
    @Published var currentCityID: String = City.defaults.first?.id ?? City.baseTimeZoneID
    @Published var deltaMinutes = 0
    @Published var isInteracting = false
    @Published var rotationDegrees = 0.0
    @Published var dialSteps = 0 {
        didSet {
            syncDeltaFromDialSteps()
        }
    }
    @Published var resetSignal = 0

    private var tickerTask: Task<Void, Never>?
    private var inertiaTask: Task<Void, Never>?
    private let stepAngleDegrees = 1.0

    var mode: Mode {
        if deltaMinutes == 0 { return .now }
        return deltaMinutes > 0 ? .future : .past
    }

    var selectedInstant: Date {
        if deltaMinutes == 0, !isInteracting {
            return now
        }
        return baseTime.addingTimeInterval(TimeInterval(deltaMinutes * 60))
    }

    init() {
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

    private func syncDeltaFromDialSteps() {
        deltaMinutes = dialSteps * 10
        if deltaMinutes == 0 {
            isInteracting = false
        }
    }

    func endInteraction() {
        isInteracting = false
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

    func isCurrentCity(_ city: City) -> Bool {
        city.id == currentCityID
    }

    func isCurrentCityByID(_ id: String) -> Bool {
        id == currentCityID
    }

    func currentCityTimeZone() -> TimeZone {
        city(for: currentCityID)?.timeZone ?? .current
    }

    func centerBottomText(for city: City, at instant: Date) -> String {
        guard !isCurrentCity(city) else { return "Current" }
        let baseOffsetSeconds = currentCityTimeZone().secondsFromGMT(for: instant)
        let cityOffsetSeconds = city.timeZone.secondsFromGMT(for: instant)
        let diffHours = (cityOffsetSeconds - baseOffsetSeconds) / 3600
        if diffHours > 0 {
            return "+\(diffHours)h"
        } else if diffHours < 0 {
            return "\(diffHours)h"
        }
        return "0h"
    }

    func setCurrentCity(id: String) {
        guard id != currentCityID else { return }
        guard let targetCity = city(for: id) else { return }
        currentCityID = id
        var reordered = cities
        reordered.removeAll { $0.id == targetCity.id }
        reordered.insert(targetCity, at: 0)
        cities = reordered
    }

    func deleteCity(id: String) {
        guard cities.count > 1 else { return }
        guard let removeIndex = cities.firstIndex(where: { $0.id == id }) else { return }

        let deletingCurrent = (id == currentCityID)
        let fallbackCurrentID: String?
        if deletingCurrent, cities.indices.contains(1) {
            fallbackCurrentID = cities[1].id
        } else {
            fallbackCurrentID = currentCityID
        }

        cities.remove(at: removeIndex)

        if deletingCurrent, let newCurrentID = fallbackCurrentID {
            currentCityID = newCurrentID
        } else if !cities.contains(where: { $0.id == currentCityID }), let firstID = cities.first?.id {
            currentCityID = firstID
        }

        // Keep the current city pinned at index 0.
        if let currentIndex = cities.firstIndex(where: { $0.id == currentCityID }), currentIndex != 0 {
            let current = cities.remove(at: currentIndex)
            cities.insert(current, at: 0)
        }

    }

    func moveCities(fromOffsets: IndexSet, toOffset: Int) {
        cities.move(fromOffsets: fromOffsets, toOffset: toOffset)
        if let firstID = cities.first?.id, currentCityID != firstID {
            currentCityID = firstID
        }
    }

    func moveCity(from sourceIndex: Int, to destinationIndex: Int) {
        guard cities.indices.contains(sourceIndex) else { return }
        let boundedDestination = max(0, min(destinationIndex, cities.count - 1))
        guard sourceIndex != boundedDestination else { return }

        let movedCity = cities.remove(at: sourceIndex)
        cities.insert(movedCity, at: boundedDestination)

        if let firstID = cities.first?.id, currentCityID != firstID {
            currentCityID = firstID
        }
    }

    private func city(for id: String) -> City? {
        cities.first { $0.id == id }
    }

    private func applyRotation(_ degrees: Double, updateStep: Bool) {
        rotationDegrees = degrees
        guard updateStep else { return }
        dialSteps = Int((degrees / stepAngleDegrees).rounded())
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
        let targetStep = Int((rotationDegrees / stepAngleDegrees).rounded())
        let targetRotation = Double(targetStep) * stepAngleDegrees
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

}
