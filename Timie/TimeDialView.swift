import SwiftUI

struct TimeDialView: View {
    private static let tickCount = 144
    private static let majorTickInterval = 6

    let diameter: CGFloat
    let rotationDegrees: Double
    let stepIndex: Int
    let resetSignal: Int
    let onDragBegan: () -> Void
    let onDragChanged: (Double) -> Void
    let onDragEnded: (Double, Double) -> Void

    @State private var dragStartAngle: Double?
    @State private var startRotationDegrees = 0.0

    var body: some View {
        let zeroIndex = 0
        let progressTicks = Self.progressTickIndices(stepIndex: stepIndex, zeroIndex: zeroIndex)
        let futureProgressColor = Color(red: 232.0 / 255.0, green: 83.0 / 255.0, blue: 52.0 / 255.0)
        let pastProgressColor = Color.black
        let defaultTickColor = Color.black.opacity(0.2)
        let activeCenterTickIndex = Self.activeCenterTickIndex(rotationDegrees: rotationDegrees)

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
                    let width: CGFloat = tick == activeCenterTickIndex ? 2 : baseWidth
                    let tickColor: Color
                    if progressTicks.contains(tick) {
                        tickColor = stepIndex > 0 ? futureProgressColor : pastProgressColor
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

    private static func progressTickIndices(stepIndex: Int, zeroIndex: Int) -> Set<Int> {
        guard stepIndex != 0 else { return [] }
        let cappedMagnitude = min(abs(stepIndex), tickCount - 1)
        let direction = stepIndex > 0 ? -1 : 1
        var indices = Set<Int>()

        for offset in 0...cappedMagnitude {
            let raw = zeroIndex + direction * offset
            let normalized = ((raw % tickCount) + tickCount) % tickCount
            indices.insert(normalized)
        }
        return indices
    }

    private static func activeCenterTickIndex(rotationDegrees: Double) -> Int {
        let degreesPerTick = 360.0 / Double(tickCount)
        let nearest = Int(((-rotationDegrees) / degreesPerTick).rounded())
        return ((nearest % tickCount) + tickCount) % tickCount
    }
}
