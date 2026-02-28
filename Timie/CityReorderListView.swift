import SwiftUI
import UIKit

struct CityListRow: Identifiable, Equatable {
    let id: String
    let index: Int
    let cityName: String
    let timeZoneID: String
    let isCurrent: Bool
}

private struct RowFramePreferenceKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]

    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

struct CityReorderListView: View {
    @ObservedObject var viewModel: TimeDialViewModel
    let rows: [CityListRow]
    let onReorderStart: (String) -> Void
    let onMove: (Int, Int) -> Void
    let onDelete: (String) -> Void

    @State private var swipeOffsets: [String: CGFloat] = [:]
    @State private var swipeStates: [String: SwipeTrackingState] = [:]
    @State private var openSwipeID: String?
    @State private var activeReorderID: String?
    @State private var activeDragOffset: CGFloat = 0
    @State private var rowFrames: [String: CGRect] = [:]
    @State private var collapsingID: String?
    @State private var scrollDragLogged = false

    private let deleteHaptics = UINotificationFeedbackGenerator()
    private let scrollSpaceName = "CityScrollSpace"
    private let rowHeight: CGFloat = 148
    private let deleteRevealWidth: CGFloat = 88
    private let collapseDuration: TimeInterval = 0.22
    private let defaultCardBackground = Color(red: 0xF7 / 255, green: 0xF7 / 255, blue: 0xF7 / 255)
    private let gestureDebugEnabled = true

    private enum SwipeIntent {
        case undecided
        case horizontal
        case vertical
    }

    private struct SwipeTrackingState {
        var intent: SwipeIntent
        var startOffset: CGFloat
        var activated = false
    }

    var body: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                ForEach(rows) { row in
                    rowView(row)
                }

                Color.clear
                    .frame(height: 220)
            }
        }
        .coordinateSpace(name: scrollSpaceName)
        .scrollIndicators(.hidden)
        .onPreferenceChange(RowFramePreferenceKey.self) { rowFrames = $0 }
        .onAppear { deleteHaptics.prepare() }
        .onChange(of: rows.map(\.id)) { _, newIDs in
            let idSet = Set(newIDs)
            swipeOffsets = swipeOffsets.filter { idSet.contains($0.key) }
            swipeStates = swipeStates.filter { idSet.contains($0.key) }
            if let openSwipeID, !idSet.contains(openSwipeID) {
                self.openSwipeID = nil
            }
            if let activeReorderID, !idSet.contains(activeReorderID) {
                self.activeReorderID = nil
                activeDragOffset = 0
            }
            if let collapsingID, !idSet.contains(collapsingID) {
                self.collapsingID = nil
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 1, coordinateSpace: .local)
                .onChanged { value in
                    guard gestureDebugEnabled else { return }
                    let dy = value.translation.height
                    guard abs(dy) > 2, !scrollDragLogged else { return }
                    scrollDragLogged = true
                    debugLog("scroll drag dy=\(Int(dy))")
                }
                .onEnded { _ in
                    scrollDragLogged = false
                }
        )
    }

    @ViewBuilder
    private func rowView(_ row: CityListRow) -> some View {
        let horizontalOffset = swipeOffsets[row.id] ?? 0
        let isSwiping = horizontalOffset < 0
        let isReordering = activeReorderID == row.id
        let isCollapsing = collapsingID == row.id

        let rowContent = ZStack(alignment: .trailing) {
            if isSwiping && rows.count > 1 {
                HStack {
                    Spacer(minLength: 0)
                    DeleteButtonView {
                        handleDelete(row.id)
                    }
                    .padding(.trailing, 20)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            HStack {
                Spacer(minLength: 0)
                CityCardView(
                    viewModel: viewModel,
                    cityID: row.id,
                    cityName: row.cityName,
                    timeZoneID: row.timeZoneID,
                    cardBackgroundColor: isSwiping ? .white : defaultCardBackground
                )
                Spacer(minLength: 0)
            }
            .frame(height: 140)
            .padding(.bottom, 8)
            .background(
                GeometryReader { geo in
                    Color.clear
                        .preference(
                            key: RowFramePreferenceKey.self,
                            value: [row.id: geo.frame(in: .named(scrollSpaceName))]
                        )
                }
            )
            .offset(x: horizontalOffset)
            .offset(y: isReordering ? activeDragOffset : 0)
            .scaleEffect(isReordering ? 1.01 : 1.0)
            .zIndex(isReordering ? 1000 : 0)
        }
        .frame(height: isCollapsing ? 0 : rowHeight, alignment: .top)
        .opacity(isCollapsing ? 0 : 1)
        .clipped()
        .contentShape(Rectangle())
        .simultaneousGesture(swipeGesture(for: row.id))
        .simultaneousGesture(reorderArmGesture(for: row.id))

        if isReordering {
            rowContent.highPriorityGesture(reorderDragGesture(for: row.id))
        } else {
            rowContent
        }
    }

    private func swipeGesture(for id: String) -> some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .local)
            .onChanged { value in
                guard activeReorderID == nil, collapsingID == nil, rows.count > 1 else { return }

                var state = swipeStates[id] ?? SwipeTrackingState(
                    intent: .undecided,
                    startOffset: swipeOffsets[id] ?? 0
                )

                let dx = value.translation.width
                let dy = value.translation.height

                if state.intent == .undecided {
                    if abs(dx) > abs(dy) + 8 {
                        state.intent = .horizontal
                        if !state.activated {
                            state.activated = true
                            debugLog("swipe activated id=\(id) dx=\(Int(dx)) dy=\(Int(dy))")
                        }
                    } else if abs(dy) > abs(dx) + 8 {
                        state.intent = .vertical
                    } else {
                        swipeStates[id] = state
                        return
                    }
                }

                guard state.intent == .horizontal else {
                    swipeStates[id] = state
                    return
                }

                if let openSwipeID, openSwipeID != id {
                    closeOpenSwipe(animated: true)
                }

                let raw = state.startOffset + dx
                swipeOffsets[id] = min(0, max(-deleteRevealWidth, raw))
                swipeStates[id] = state
            }
            .onEnded { _ in
                guard activeReorderID == nil else { return }

                let state = swipeStates[id] ?? SwipeTrackingState(
                    intent: .undecided,
                    startOffset: swipeOffsets[id] ?? 0
                )
                swipeStates[id] = nil

                guard state.intent == .horizontal else { return }

                let currentOffset = swipeOffsets[id] ?? 0
                let shouldOpen = currentOffset <= -(deleteRevealWidth * 0.45)

                withAnimation(.interactiveSpring(response: 0.24, dampingFraction: 0.9)) {
                    if shouldOpen {
                        swipeOffsets[id] = -deleteRevealWidth
                        openSwipeID = id
                    } else {
                        swipeOffsets[id] = 0
                        if openSwipeID == id {
                            openSwipeID = nil
                        }
                    }
                }
            }
    }

    private func reorderArmGesture(for id: String) -> some Gesture {
        LongPressGesture(minimumDuration: 0.28)
            .onEnded { _ in
                beginReorder(id)
            }
    }

    private func reorderDragGesture(for id: String) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(scrollSpaceName))
            .onChanged { value in
                guard activeReorderID == id else { return }
                activeDragOffset = value.translation.height
                debugLog("reorder drag dy=\(Int(value.translation.height))")
                updateReorderTarget(for: id, translationY: value.translation.height)
            }
            .onEnded { _ in
                endReorder(id)
            }
    }

    private func beginReorder(_ id: String) {
        guard collapsingID == nil else { return }
        guard activeReorderID == nil else { return }

        closeOpenSwipe(animated: true)
        activeReorderID = id
        activeDragOffset = 0
        debugLog("reorder armed id=\(id)")
        onReorderStart(id)
    }

    private func endReorder(_ id: String) {
        guard activeReorderID == id else { return }
        withAnimation(.interactiveSpring(response: 0.24, dampingFraction: 0.9)) {
            activeDragOffset = 0
        }
        activeReorderID = nil
    }

    private func updateReorderTarget(for draggingID: String, translationY: CGFloat) {
        guard activeReorderID == draggingID else { return }
        guard let currentIndex = rows.firstIndex(where: { $0.id == draggingID }) else { return }
        guard let draggingFrame = rowFrames[draggingID] else { return }

        let draggedMidY = draggingFrame.midY + translationY
        let candidates = rows.compactMap { row -> (id: String, midY: CGFloat)? in
            guard let frame = rowFrames[row.id] else { return nil }
            return (row.id, frame.midY)
        }

        guard !candidates.isEmpty else { return }
        guard let nearestID = candidates.min(by: { abs($0.midY - draggedMidY) < abs($1.midY - draggedMidY) })?.id,
              let targetIndex = rows.firstIndex(where: { $0.id == nearestID }) else {
            return
        }

        guard targetIndex != currentIndex else { return }

        withAnimation(.interactiveSpring(response: 0.26, dampingFraction: 0.88)) {
            onMove(currentIndex, targetIndex)
        }
    }

    private func closeOpenSwipe(animated: Bool) {
        guard let openSwipeID else { return }
        if animated {
            withAnimation(.interactiveSpring(response: 0.24, dampingFraction: 0.9)) {
                swipeOffsets[openSwipeID] = 0
            }
        } else {
            swipeOffsets[openSwipeID] = 0
        }
        self.openSwipeID = nil
    }

    private func handleDelete(_ id: String) {
        guard rows.count > 1 else { return }
        guard collapsingID == nil else { return }

        closeOpenSwipe(animated: false)
        deleteHaptics.notificationOccurred(.error)
        deleteHaptics.prepare()

        withAnimation(.easeInOut(duration: collapseDuration)) {
            collapsingID = id
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + collapseDuration) {
            let noAnimation = Transaction(animation: nil)
            withTransaction(noAnimation) {
                onDelete(id)
            }
            collapsingID = nil
            swipeOffsets[id] = nil
            swipeStates[id] = nil
            if openSwipeID == id {
                openSwipeID = nil
            }
        }
    }

    private func debugLog(_ message: String) {
        guard gestureDebugEnabled else { return }
        print("[DBG] \(message)")
    }
}
