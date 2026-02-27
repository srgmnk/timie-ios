import SwiftUI
import UIKit

struct CityListRow: Identifiable, Equatable {
    let id: String
    let cityName: String
    let timeText: String
    let dayNightSymbol: String
    let dateText: String
    let centerBottomText: String
    let utcOffsetValueText: String
    let isCurrent: Bool
}

struct CityReorderListView: UIViewControllerRepresentable {
    let rows: [CityListRow]
    let onReorderStart: (String) -> Void
    let onMove: (Int, Int) -> Void
    let onDelete: (String) -> Void

    func makeUIViewController(context: Context) -> CityReorderListController {
        CityReorderListController(
            rows: rows,
            onReorderStart: onReorderStart,
            onMove: onMove,
            onDelete: onDelete
        )
    }

    func updateUIViewController(_ uiViewController: CityReorderListController, context: Context) {
        uiViewController.updateRows(rows)
    }
}

final class CityReorderListController: UIViewController, UICollectionViewDelegate {
    private var rows: [CityListRow]
    private var rowByID: [String: CityListRow]
    private var pendingRows: [CityListRow]?

    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Int, String>!
    private var cellRegistration: UICollectionView.CellRegistration<UICollectionViewListCell, String>!
    private var longPressRecognizer: UILongPressGestureRecognizer!

    private var isInteractiveReordering = false
    private var isSwipeInteractionInFlight = false
    private var swipeClearWorkItem: DispatchWorkItem?

    private var deleteRunCounter = 0
    private var activeDeleteRunID: Int?
    private var activeDeleteRunApplyCount = 0
    private var activeDeletingCityID: String?

    private let deleteHaptics = UINotificationFeedbackGenerator()

    private let onReorderStart: (String) -> Void
    private let onMove: (Int, Int) -> Void
    private let onDelete: (String) -> Void

    init(
        rows: [CityListRow],
        onReorderStart: @escaping (String) -> Void,
        onMove: @escaping (Int, Int) -> Void,
        onDelete: @escaping (String) -> Void
    ) {
        self.rows = rows
        self.rowByID = Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0) })
        self.onReorderStart = onReorderStart
        self.onMove = onMove
        self.onDelete = onDelete
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        var listConfig = UICollectionLayoutListConfiguration(appearance: .plain)
        listConfig.showsSeparators = false
        listConfig.backgroundColor = .clear
        listConfig.leadingSwipeActionsConfigurationProvider = nil
        listConfig.trailingSwipeActionsConfigurationProvider = { [weak self] indexPath in
            guard let self else { return nil }
            guard !self.isInteractiveReordering, !self.isSwipeInteractionInFlight else { return nil }
            guard self.rows.count > 1 else { return nil }
            guard let itemID = self.dataSource.itemIdentifier(for: indexPath),
                  let row = self.rowByID[itemID] else { return nil }

            self.markSwipeInteractionInFlight(reason: "provider")

            let action = UIContextualAction(style: .destructive, title: nil) { [weak self] _, _, completion in
                guard let self else {
                    completion(false)
                    return
                }

                guard let deleteIndex = self.rows.firstIndex(where: { $0.id == itemID }) else {
                    self.scheduleSwipeInteractionClear(delay: 0.2)
                    completion(false)
                    return
                }

                self.deleteRunCounter += 1
                let runID = self.deleteRunCounter
                self.activeDeleteRunID = runID
                self.activeDeleteRunApplyCount = 0
                self.activeDeletingCityID = itemID

                let beforeIDs = self.rows.map(\.id).joined(separator: ",")
                let currentBefore = self.rows.first(where: { $0.isCurrent })?.id ?? "none"
                self.logDelete(
                    "run=\(runID) begin index=\(deleteIndex) id=\(itemID) wasCurrent=\(row.isCurrent) citiesBefore=[\(beforeIDs)] currentBefore=\(currentBefore)"
                )

                // Fire exactly once per delete before model/snapshot update.
                self.deleteHaptics.notificationOccurred(.error)
                self.deleteHaptics.prepare()

                self.markSwipeInteractionInFlight(reason: "delete_action")
                self.onDelete(itemID)
                self.scheduleSwipeInteractionClear(delay: 0.2)
                completion(true)
            }

            action.image = UIImage(systemName: "trash.fill")
            action.backgroundColor = UIColor(red: 0xE8 / 255, green: 0x53 / 255, blue: 0x34 / 255, alpha: 1)

            let config = UISwipeActionsConfiguration(actions: [action])
            config.performsFirstActionWithFullSwipe = false
            return config
        }

        let layout = UICollectionViewCompositionalLayout.list(using: listConfig)
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .clear
        collectionView.isScrollEnabled = true
        collectionView.alwaysBounceVertical = true
        collectionView.reorderingCadence = .immediate
        collectionView.delegate = self
        collectionView.contentInset = UIEdgeInsets(top: 66, left: 0, bottom: 200, right: 0)
        collectionView.scrollIndicatorInsets = collectionView.contentInset

        cellRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, String> { [weak self] cell, _, itemID in
            guard let self, let row = self.rowByID[itemID] else { return }
            self.configure(cell: cell, with: row)
        }

        dataSource = UICollectionViewDiffableDataSource<Int, String>(collectionView: collectionView) { [weak self] collectionView, indexPath, itemID in
            guard let self else { return nil }
            return collectionView.dequeueConfiguredReusableCell(using: self.cellRegistration, for: indexPath, item: itemID)
        }
        dataSource.reorderingHandlers.canReorderItem = { [weak self] itemID in
            self?.rowByID[itemID] != nil
        }
        dataSource.reorderingHandlers.didReorder = { [weak self] transaction in
            guard let self else { return }
            // Keep local order synced with the final diffable order and notify ViewModel once.
            var updatedRows: [CityListRow] = []
            updatedRows.reserveCapacity(transaction.finalSnapshot.itemIdentifiers.count)
            for itemID in transaction.finalSnapshot.itemIdentifiers {
                if let row = self.rowByID[itemID] {
                    updatedRows.append(row)
                }
            }

            guard !updatedRows.isEmpty else { return }
            self.rows = updatedRows
            self.rowByID = Dictionary(uniqueKeysWithValues: updatedRows.map { ($0.id, $0) })

            if let difference = transaction.difference.inferringMoves() as CollectionDifference<String>? {
                for change in difference {
                    if case let .insert(offset: destination, element: movedID, associatedWith: sourceAssoc?) = change {
                        if let source = difference.first(where: {
                            if case let .remove(_, element, associatedWith) = $0 {
                                return associatedWith == sourceAssoc && element == movedID
                            }
                            return false
                        }), case let .remove(offset: sourceIndex, _, _) = source {
                            self.onMove(sourceIndex, destination)
                            break
                        }
                    }
                }
            }
        }

        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        longPressRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPressRecognizer.minimumPressDuration = 0.24
        collectionView.addGestureRecognizer(longPressRecognizer)

        deleteHaptics.prepare()

        applySnapshot(reason: "initial", animatingDifferences: false)
    }

    func updateRows(_ newRows: [CityListRow]) {
        rows = newRows
        rowByID = Dictionary(uniqueKeysWithValues: newRows.map { ($0.id, $0) })

        if let runID = activeDeleteRunID {
            let afterIDs = newRows.map(\.id).joined(separator: ",")
            let currentAfter = newRows.first(where: { $0.isCurrent })?.id ?? "none"
            logDelete("run=\(runID) afterMutation citiesAfter=[\(afterIDs)] currentAfter=\(currentAfter)")
            if let deletingID = activeDeletingCityID, newRows.contains(where: { $0.id == deletingID }) {
                logDelete("run=\(runID) WARNING deleted city id=\(deletingID) is still present before snapshot apply")
            }

            // Delete-current path must be atomic: one model mutation -> one immediate snapshot apply.
            pendingRows = nil
            applySnapshot(reason: "deleteMutation", animatingDifferences: true)
            return
        }

        if shouldQueueUpdate {
            pendingRows = newRows
            return
        }

        applySnapshot(reason: "updateRows", animatingDifferences: true)
    }

    private func applySnapshot(reason: String, animatingDifferences: Bool) {
        assert(Thread.isMainThread)

        let runID = activeDeleteRunID
        if let runID {
            activeDeleteRunApplyCount += 1
            logDelete(
                "run=\(runID) snapshotApply start count=\(rows.count) top3=[\(rows.prefix(3).map(\.id).joined(separator: ","))] reason=\(reason) applyCount=\(activeDeleteRunApplyCount)"
            )
            if activeDeleteRunApplyCount > 1 {
                logDelete("run=\(runID) WARNING double-apply detector triggered applyCount=\(activeDeleteRunApplyCount)")
            }
        }

        var snapshot = NSDiffableDataSourceSnapshot<Int, String>()
        snapshot.appendSections([0])
        snapshot.appendItems(rows.map(\.id), toSection: 0)
        dataSource.apply(snapshot, animatingDifferences: animatingDifferences) { [weak self] in
            guard let self else { return }
            if let runID = self.activeDeleteRunID {
                self.logDelete(
                    "run=\(runID) snapshotApply end itemCount=\(self.rows.count) top3=[\(self.rows.prefix(3).map(\.id).joined(separator: ","))]"
                )
                self.activeDeleteRunID = nil
                self.activeDeleteRunApplyCount = 0
                self.activeDeletingCityID = nil
            }
        }
    }

    private func configure(cell: UICollectionViewListCell, with row: CityListRow) {
        cell.isOpaque = false
        cell.backgroundColor = .clear
        cell.contentView.backgroundColor = .clear
        cell.layer.backgroundColor = UIColor.clear.cgColor
        cell.layer.shadowOpacity = 0
        cell.selectedBackgroundView = {
            let view = UIView()
            view.backgroundColor = .clear
            return view
        }()
        cell.backgroundConfiguration = UIBackgroundConfiguration.clear()
        cell.contentConfiguration = UIHostingConfiguration {
            HStack {
                Spacer(minLength: 0)
                CityCardView(
                    cityName: row.cityName,
                    timeText: row.timeText,
                    dayNightSymbol: row.dayNightSymbol,
                    dateText: row.dateText,
                    centerBottomText: row.centerBottomText,
                    utcOffsetValueText: row.utcOffsetValueText,
                    cardBackgroundColor: Color(red: 0xF7 / 255, green: 0xF7 / 255, blue: 0xF7 / 255)
                )
                Spacer(minLength: 0)
            }
            .padding(.bottom, 8)
        }
        .margins(.all, 0)
    }

    @objc
    private func handleLongPress(_ recognizer: UILongPressGestureRecognizer) {
        let location = recognizer.location(in: collectionView)

        switch recognizer.state {
        case .began:
            guard let indexPath = collectionView.indexPathForItem(at: location),
                  let itemID = dataSource.itemIdentifier(for: indexPath) else { return }

            isInteractiveReordering = true
            onReorderStart(itemID)
            collectionView.beginInteractiveMovementForItem(at: indexPath)
        case .changed:
            collectionView.updateInteractiveMovementTargetPosition(location)
        case .ended:
            collectionView.endInteractiveMovement()
            endReorderSession()
        default:
            collectionView.cancelInteractiveMovement()
            endReorderSession()
        }
    }

    private func endReorderSession() {
        isInteractiveReordering = false
        flushPendingRowsIfPossible()
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        scheduleSwipeInteractionClear(delay: decelerate ? 0.25 : 0.15)
        if !decelerate {
            flushPendingRowsIfPossible()
        }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        scheduleSwipeInteractionClear(delay: 0.1)
        flushPendingRowsIfPossible()
    }

    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        scheduleSwipeInteractionClear(delay: 0.1)
        flushPendingRowsIfPossible()
    }

    private var shouldQueueUpdate: Bool {
        isInteractiveReordering || isSwipeInteractionInFlight || isSwipeInteractionActive()
    }

    private func flushPendingRowsIfPossible() {
        guard !shouldQueueUpdate else { return }
        guard let pendingRows else { return }
        self.pendingRows = nil
        updateRows(pendingRows)
    }

    private func markSwipeInteractionInFlight(reason: String) {
        isSwipeInteractionInFlight = true
        scheduleSwipeInteractionClear(delay: 0.35)
        _ = reason
    }

    private func scheduleSwipeInteractionClear(delay: TimeInterval) {
        swipeClearWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.isSwipeInteractionInFlight = false
        }
        swipeClearWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func isSwipeInteractionActive() -> Bool {
        let hasActiveSwipeGesture = collectionView.gestureRecognizers?.contains(where: { gesture in
            let name = NSStringFromClass(type(of: gesture))
            let isSwipeGesture = name.localizedCaseInsensitiveContains("swipe")
            let isActive = gesture.state == .began || gesture.state == .changed
            return isSwipeGesture && isActive
        }) ?? false

        let hasVisibleSwipeOverlay = collectionView.subviews.contains(where: { view in
            let name = NSStringFromClass(type(of: view))
            let isSwipeView = name.localizedCaseInsensitiveContains("swipe")
            return isSwipeView && !view.isHidden && view.alpha > 0.01 && view.bounds.width > 0 && view.bounds.height > 0
        })

        return hasActiveSwipeGesture || hasVisibleSwipeOverlay
    }

    private func logDelete(_ message: String) {
        guard DebugSettings.enableCityDeleteDebug else { return }
        print("[DELETE] \(message)")
    }
}
