import SwiftUI

#if DEBUG
let ENABLE_DIAL_TICK_DEBUG = true
#else
let ENABLE_DIAL_TICK_DEBUG = false
#endif

struct TimeDialView: View {
    private static let tickCount = 144
    private static let majorTickInterval = 6
    private static let minutesPerStep = 10

    let diameter: CGFloat
    let rotationDegrees: Double
    let stepIndex: Int // relStep: +future, -past
    let resetSignal: Int
    let onDragBegan: () -> Void
    let onDragChanged: (Double) -> Void
    let onDragEnded: (Double, Double) -> Void

    @State private var dragStartAngle: Double?
    @State private var startRotationDegrees = 0.0
    @State private var isDragging = false
    @State private var lastDebugLogAt = Date.distantPast
    @State private var lastDebugSnapshot: DebugSnapshot?

    var body: some View {
        let filledProgressColor = Color(red: 232.0 / 255.0, green: 83.0 / 255.0, blue: 52.0 / 255.0)
        let defaultTickColor = Color.black.opacity(0.2)
        let relStep = stepIndex
        let centerTickIndex = Self.activeCenterTickIndex(rotationDegrees: rotationDegrees)
        let progressTickSequence = Self.progressTickSequence(relStep: relStep, centerTickIndex: centerTickIndex)
        let progressTicks = Set(progressTickSequence)
        let filledBoundaryTickIndex = progressTickSequence.last

        ZStack {
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let outerRadius = (diameter / 2) - 16
                let minorLength: CGFloat = 16
                let majorLength: CGFloat = 24
                let minorWidth: CGFloat = 1
                let majorWidth: CGFloat = 1

                let degreesPerTick = 360.0 / Double(Self.tickCount)

                for tick in 0..<Self.tickCount {
                    let isMajor = tick.isMultiple(of: Self.majorTickInterval)
                    let angleDegrees = (Double(tick) * degreesPerTick) + rotationDegrees - 90
                    let angle = angleDegrees * .pi / 180
                    let length = isMajor ? majorLength : minorLength
                    let baseWidth = isMajor ? majorWidth : minorWidth
                    let width: CGFloat = tick == centerTickIndex ? 2 : baseWidth
                    let tickColor: Color
                    if progressTicks.contains(tick) {
                        tickColor = filledProgressColor
                    } else {
                        tickColor = defaultTickColor
                    }

                    let start = CGPoint(
                        x: center.x + cos(angle) * (outerRadius - length),
                        y: center.y + sin(angle) * (outerRadius - length)
                    )
                    let end = CGPoint(
                        x: center.x + cos(angle) * outerRadius,
                        y: center.y + sin(angle) * outerRadius
                    )
                    let mid = CGPoint(
                        x: (start.x + end.x) / 2,
                        y: (start.y + end.y) / 2
                    )

                    let localRect = CGRect(
                        x: -length / 2,
                        y: -width / 2,
                        width: length,
                        height: width
                    )
                    let roundedTick = Path(
                        roundedRect: localRect,
                        cornerSize: CGSize(width: 1, height: 1)
                    )
                    let transform = CGAffineTransform(translationX: mid.x, y: mid.y)
                        .rotated(by: angle)
                    let tickPath = roundedTick.applying(transform)
                    context.fill(tickPath, with: .color(tickColor))
                }
            }
            .frame(width: diameter, height: diameter)

            if ENABLE_DIAL_TICK_DEBUG {
                debugTickOverlay(
                    centerTickIndex: centerTickIndex,
                    filledTicks: progressTicks,
                    boundaryTickIndex: filledBoundaryTickIndex
                )
            }
        }
        .frame(width: diameter, height: diameter)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    isDragging = true
                    onDragBegan()
                    let center = CGPoint(x: diameter / 2, y: diameter / 2)
                    let angle = Self.angleDegrees(point: value.location, center: center)

                    if dragStartAngle == nil {
                        dragStartAngle = angle
                        startRotationDegrees = rotationDegrees
                    }

                    guard let dragStartAngle else { return }
                    let diff = Self.normalizedDeltaDegrees(from: dragStartAngle, to: angle)
                    let currentRotation = startRotationDegrees + diff
                    onDragChanged(currentRotation)
                }
                .onEnded { value in
                    let center = CGPoint(x: diameter / 2, y: diameter / 2)
                    let currentAngle = Self.angleDegrees(point: value.location, center: center)
                    let predictedAngle = Self.angleDegrees(point: value.predictedEndLocation, center: center)
                    let currentDiff = Self.normalizedDeltaDegrees(from: dragStartAngle ?? currentAngle, to: currentAngle)
                    let predictedDiff = Self.normalizedDeltaDegrees(from: dragStartAngle ?? currentAngle, to: predictedAngle)
                    let currentRotation = startRotationDegrees + currentDiff
                    let predictedRotation = startRotationDegrees + predictedDiff

                    dragStartAngle = nil
                    startRotationDegrees = currentRotation
                    isDragging = false
                    onDragEnded(currentRotation, predictedRotation)
                }
        )
        .onChange(of: resetSignal) { _, _ in
            dragStartAngle = nil
            startRotationDegrees = rotationDegrees
            isDragging = false
            lastDebugSnapshot = nil
        }
        .onChange(of: rotationDegrees) { _, _ in
            guard ENABLE_DIAL_TICK_DEBUG else { return }
            logDialDebugIfNeeded(
                centerTickIndex: centerTickIndex,
                relStep: relStep,
                filledTicksInOrder: progressTickSequence
            )
        }
    }

    private static func angleDegrees(point: CGPoint, center: CGPoint) -> Double {
        let dx = point.x - center.x
        let dy = point.y - center.y
        return atan2(dy, dx) * 180 / .pi
    }

    private static func normalizedDeltaDegrees(from start: Double, to current: Double) -> Double {
        var delta = current - start
        while delta > 180 { delta -= 360 }
        while delta < -180 { delta += 360 }
        return delta
    }

    private static func progressTickSequence(relStep: Int, centerTickIndex: Int) -> [Int] {
        guard relStep != 0 else { return [] }
        let steps = min(abs(relStep), tickCount - 1)
        let direction = relStep > 0 ? 1 : -1
        var indices: [Int] = []
        indices.reserveCapacity(steps)

        for offset in 1...steps {
            if direction > 0 {
                let clockwiseDistance = offset
                let tick = (centerTickIndex + clockwiseDistance) % tickCount
                indices.append(tick)
            } else {
                let counterclockwiseDistance = offset
                let tick = ((centerTickIndex - counterclockwiseDistance) % tickCount + tickCount) % tickCount
                indices.append(tick)
            }
        }
        return indices
    }

    private static func activeCenterTickIndex(rotationDegrees: Double) -> Int {
        let degreesPerTick = 360.0 / Double(tickCount)
        let nearest = Int(((-rotationDegrees) / degreesPerTick).rounded())
        return ((nearest % tickCount) + tickCount) % tickCount
    }

    private static func relativeStep(from centerTickIndex: Int, to tickIndex: Int) -> Int {
        let clockwiseDistance = (tickIndex - centerTickIndex + tickCount) % tickCount
        let counterclockwiseDistance = (centerTickIndex - tickIndex + tickCount) % tickCount

        if clockwiseDistance == 0 { return 0 }
        if clockwiseDistance <= counterclockwiseDistance {
            return clockwiseDistance
        }
        return -counterclockwiseDistance
    }

    @ViewBuilder
    private func debugTickOverlay(centerTickIndex: Int, filledTicks: Set<Int>, boundaryTickIndex: Int?) -> some View {
        let center = CGPoint(x: diameter / 2, y: diameter / 2)
        let outerRadius = (diameter / 2) - 16
        let degreesPerTick = 360.0 / Double(Self.tickCount)
        let dotRadius = outerRadius - 8
        let labelRadius = outerRadius - 32
        let centerMarkerRadius = outerRadius - 44
        let shownDebugLabels = Set((-12...12).compactMap { relative in
            let index = ((centerTickIndex + relative) % Self.tickCount + Self.tickCount) % Self.tickCount
            return index
        })

        ForEach(0..<Self.tickCount, id: \.self) { tick in
            let angleDegrees = (Double(tick) * degreesPerTick) + rotationDegrees - 90
            let angle = angleDegrees * .pi / 180
            let relativeIndex = Self.relativeStep(from: centerTickIndex, to: tick)
            let dotPoint = CGPoint(
                x: center.x + cos(angle) * dotRadius,
                y: center.y + sin(angle) * dotRadius
            )
            let labelPoint = CGPoint(
                x: center.x + cos(angle) * labelRadius,
                y: center.y + sin(angle) * labelRadius
            )

            Circle()
                .fill(filledTicks.contains(tick) ? .red : Color.gray.opacity(0.12))
                .frame(width: 4, height: 4)
                .position(dotPoint)

            if shownDebugLabels.contains(tick) {
                Text(relativeIndex >= 0 ? "+\(relativeIndex)" : "\(relativeIndex)")
                    .font(.system(size: 8, weight: .regular, design: .monospaced))
                    .foregroundStyle(Color.gray.opacity(0.9))
                    .position(labelPoint)
            }
        }

        let centerAngleDegrees = (Double(centerTickIndex) * degreesPerTick) + rotationDegrees - 90
        let centerAngle = centerAngleDegrees * .pi / 180
        let centerMarkerPoint = CGPoint(
            x: center.x + cos(centerAngle) * centerMarkerRadius,
            y: center.y + sin(centerAngle) * centerMarkerRadius
        )
        Circle()
            .fill(.blue)
            .frame(width: 8, height: 8)
            .position(centerMarkerPoint)
        Text("C")
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundStyle(.blue)
            .position(
                x: centerMarkerPoint.x,
                y: centerMarkerPoint.y - 10
            )

        if let boundaryTickIndex {
            let boundaryAngleDegrees = (Double(boundaryTickIndex) * degreesPerTick) + rotationDegrees - 90
            let boundaryAngle = boundaryAngleDegrees * .pi / 180
            let boundaryPoint = CGPoint(
                x: center.x + cos(boundaryAngle) * (centerMarkerRadius + 10),
                y: center.y + sin(boundaryAngle) * (centerMarkerRadius + 10)
            )
            Circle()
                .fill(.green)
                .frame(width: 7, height: 7)
                .position(boundaryPoint)
        }
    }

    private func logDialDebugIfNeeded(centerTickIndex: Int, relStep: Int, filledTicksInOrder: [Int]) {
        guard isDragging else { return }

        let offsetMinutes = relStep * Self.minutesPerStep
        let directionSign = relStep == 0 ? 0 : (relStep > 0 ? 1 : -1)
        let stepsFilled = abs(relStep)
        let firstFilledTickIndex = filledTicksInOrder.first ?? -1
        let lastFilledTickIndex = filledTicksInOrder.last ?? -1
        let filledRange: String = {
            guard relStep != 0 else { return "[]" }
            if relStep > 0 { return "[+1...+\(relStep)]" }
            return "[-1...\(relStep)]"
        }()
        let snapshot = DebugSnapshot(
            offsetMinutes: offsetMinutes,
            stepsFilled: stepsFilled,
            directionSign: directionSign,
            firstFilledTickIndex: firstFilledTickIndex,
            lastFilledTickIndex: lastFilledTickIndex
        )
        guard snapshot != lastDebugSnapshot else { return }

        let now = Date()
        guard now.timeIntervalSince(lastDebugLogAt) >= 0.1 else { return }

        let normalizedAngle = ((rotationDegrees.truncatingRemainder(dividingBy: 360)) + 360)
            .truncatingRemainder(dividingBy: 360)
        let angleDelta = rotationDegrees
        let sampleRelative = filledTicksInOrder.prefix(12).map { tick in
            Self.relativeStep(from: centerTickIndex, to: tick)
        }

        print(
            "[DIALDBG] angleRaw=\(String(format: "%.2f", rotationDegrees)) " +
            "angleNorm=\(String(format: "%.2f", normalizedAngle)) " +
            "angleDelta=\(String(format: "%.2f", angleDelta)) relStep=\(relStep) " +
            "offsetMin=\(offsetMinutes) sign=\(directionSign) steps=\(stepsFilled) " +
            "center=0 first=\(firstFilledTickIndex) last=\(lastFilledTickIndex) " +
            "filledRange=\(filledRange) filledRel=\(sampleRelative)"
        )

        lastDebugSnapshot = snapshot
        lastDebugLogAt = now
    }

    private struct DebugSnapshot: Equatable {
        let offsetMinutes: Int
        let stepsFilled: Int
        let directionSign: Int
        let firstFilledTickIndex: Int
        let lastFilledTickIndex: Int
    }
}
