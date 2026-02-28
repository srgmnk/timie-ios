import SwiftUI

struct TimeDialView: View {
    private static let tickCount = 288
    private static let majorTickInterval = 2
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

    var body: some View {
        let defaultTickColor = Color.black.opacity(0.2)
        let offsetStepsSigned = stepIndex
        let offsetMinutes = offsetStepsSigned * Self.minutesPerStep
        let futureFillColor = Color(red: 0xE8 / 255, green: 0x53 / 255, blue: 0x34 / 255)
        let pastFillColor = Color(red: 0x22 / 255, green: 0x22 / 255, blue: 0x22 / 255)
        let fillColor = offsetStepsSigned > 0 ? futureFillColor : pastFillColor
        let centerTickIndex = Self.activeCenterTickIndex(rotationDegrees: rotationDegrees)
        let filledSet = Self.filledTickIndices(
            centerTickIndex: centerTickIndex,
            offsetStepsSigned: offsetStepsSigned
        )

        ZStack {
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let outerRadius = (diameter / 2) - 16
                let majorLength: CGFloat = 24
                let minorLength: CGFloat = majorLength / 2
                let minorWidth: CGFloat = 1
                let majorWidth: CGFloat = 1

                let degreesPerTick = 360.0 / Double(Self.tickCount)

                // Layer 1: base ticks in gray.
                for tick in 0..<Self.tickCount {
                    let tickPath = Self.tickPath(
                        tick: tick,
                        center: center,
                        outerRadius: outerRadius,
                        minorLength: minorLength,
                        majorLength: majorLength,
                        minorWidth: minorWidth,
                        majorWidth: majorWidth,
                        lineWidth: 1,
                        degreesPerTick: degreesPerTick,
                        rotationDegrees: rotationDegrees
                    )
                    context.fill(tickPath, with: .color(defaultTickColor))
                }

                // Layer 2: filled ticks overpainted with sign-based color.
                if offsetMinutes != 0 {
                    for tick in 0..<Self.tickCount {
                        guard filledSet.contains(tick) else { continue }
                        let tickPath = Self.tickPath(
                            tick: tick,
                            center: center,
                            outerRadius: outerRadius,
                            minorLength: minorLength,
                            majorLength: majorLength,
                            minorWidth: minorWidth,
                            majorWidth: majorWidth,
                            lineWidth: 2,
                            degreesPerTick: degreesPerTick,
                            rotationDegrees: rotationDegrees
                        )
                        context.fill(tickPath, with: .color(fillColor))
                    }
                }
            }
            .frame(width: diameter, height: diameter)
        }
        .frame(width: diameter, height: diameter)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
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
                    onDragEnded(currentRotation, predictedRotation)
                }
        )
        .onChange(of: resetSignal) { _, _ in
            dragStartAngle = nil
            startRotationDegrees = rotationDegrees
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

    private static func tickIndex(for relativeStep: Int, centerTickIndex: Int) -> Int {
        // Positive relStep must be on the visual LEFT side of center.
        ((centerTickIndex - relativeStep) % tickCount + tickCount) % tickCount
    }

    private static func clampedOffsetSteps(_ offsetStepsSigned: Int) -> Int {
        let maxOffsetSteps = (tickCount - 1) / 2
        return max(-maxOffsetSteps, min(maxOffsetSteps, offsetStepsSigned))
    }

    private static func isTickFilled(
        tick: Int,
        centerTickIndex: Int,
        offsetStepsSigned: Int
    ) -> Bool {
        let clamped = clampedOffsetSteps(offsetStepsSigned)
        guard clamped != 0 else { return false }
        let tickRelIndex = relativeStep(from: centerTickIndex, to: tick)
        let filledBoundary = clamped * 2 // convert 10-minute steps into 5-minute tick steps

        if filledBoundary > 0 {
            return tickRelIndex >= 0 && tickRelIndex <= filledBoundary
        }

        return tickRelIndex <= 0 && tickRelIndex >= filledBoundary
    }

    private static func filledTickIndices(centerTickIndex: Int, offsetStepsSigned: Int) -> Set<Int> {
        guard offsetStepsSigned != 0 else { return [] }
        return Set((0..<tickCount).filter { tick in
            isTickFilled(tick: tick, centerTickIndex: centerTickIndex, offsetStepsSigned: offsetStepsSigned)
        })
    }

    private static func activeCenterTickIndex(rotationDegrees: Double) -> Int {
        let degreesPerTick = 360.0 / Double(tickCount)
        let nearest = Int(((-rotationDegrees) / degreesPerTick).rounded())
        return ((nearest % tickCount) + tickCount) % tickCount
    }

    private static func relativeStep(from centerTickIndex: Int, to tickIndex: Int) -> Int {
        let half = tickCount / 2
        var delta = centerTickIndex - tickIndex
        delta = ((delta + half) % tickCount + tickCount) % tickCount - half
        return delta
    }

    private static func tickPath(
        tick: Int,
        center: CGPoint,
        outerRadius: CGFloat,
        minorLength: CGFloat,
        majorLength: CGFloat,
        minorWidth: CGFloat,
        majorWidth: CGFloat,
        lineWidth: CGFloat,
        degreesPerTick: Double,
        rotationDegrees: Double
    ) -> Path {
        let isMajor = tick.isMultiple(of: Self.majorTickInterval)
        let angleDegrees = (Double(tick) * degreesPerTick) + rotationDegrees - 90
        let angleRadians = angleDegrees * .pi / 180
        let angle = CGFloat(angleRadians)
        let cosAngle = CGFloat(cos(angleRadians))
        let sinAngle = CGFloat(sin(angleRadians))
        let length = isMajor ? majorLength : minorLength
        let _ = isMajor ? majorWidth : minorWidth
        let width = lineWidth

        let start = CGPoint(
            x: center.x + cosAngle * (outerRadius - length),
            y: center.y + sinAngle * (outerRadius - length)
        )
        let end = CGPoint(
            x: center.x + cosAngle * outerRadius,
            y: center.y + sinAngle * outerRadius
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
        return roundedTick.applying(transform)
    }
}
