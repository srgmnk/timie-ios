import SwiftUI
import UIKit
import Combine

struct TimeDialScreen: View {
    @StateObject private var viewModel = TimeDialViewModel()
    @StateObject private var currentLocationProvider = CurrentLocationCityProvider()
    @EnvironmentObject private var cityStore: CityStore
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.appTheme) private var theme
    @State private var lastSnappedOffsetSteps = 0
    @State private var isDraggingSessionActive = false
    @State private var dialHeight: CGFloat = 260
    @State private var isAddCitySheetPresented = false
    @State private var isSettingsSheetPresented = false
    @State private var cityBeingRenamed: City?
    @State private var pendingAddedCityItem: CitySearchItem?
    @AppStorage(CityViewPreference.storageKey) private var cityViewPreferenceRawValue = CityViewPreference.basic.rawValue
    @StateObject private var emptyStateQuoteProvider = EmptyStateQuoteProvider()

    private let dialSize: CGFloat = 512
    private let dialCenterYOffset: CGFloat = 125
    private let dialOverlayHeight: CGFloat = 260
    private let cityListDesiredBottomGap: CGFloat = 130
    private let topButtonTopOffset: CGFloat = 60
    private let topButtonBarHeight: CGFloat = 48
    private let topButtonBarTopPadding: CGFloat = 1
    private let logoHeight: CGFloat = 15
    private let logoWidth: CGFloat = 49
    private let smallTickHaptics = UIImpactFeedbackGenerator(style: .light)
    private let bigTickHaptics = UIImpactFeedbackGenerator(style: .heavy)
    private let zeroTickHaptics = UINotificationFeedbackGenerator()
    private let resetNotificationHaptics = UINotificationFeedbackGenerator()

    private var hapticsEnabled: Bool {
        #if targetEnvironment(simulator)
        false
        #else
        true
        #endif
    }

    private var selectedCityViewPreference: CityViewPreference {
        CityViewPreference.from(rawValue: cityViewPreferenceRawValue)
    }

    var body: some View {
        GeometryReader { geo in
            let topSafeInset = resolvedTopSafeAreaInset(from: geo)
            let topControlsTop = topButtonTopOffset - max(0, 59 - topSafeInset)
            let isCitiesEmpty = cityStore.cities.isEmpty
            let sharedLogoTopInset = topSafeInset + topButtonBarTopPadding + ((topButtonBarHeight - logoHeight) / 2)

            ZStack(alignment: .bottom) {
                SheetStyle.appScreenBackground(for: theme)
                    .ignoresSafeArea()

                Group {
                    if isCitiesEmpty {
                        ZStack(alignment: .top) {
                            MainEmptyStateQuoteView(quote: emptyStateQuoteProvider.currentQuote)
                                .frame(width: geo.size.width, height: geo.size.height, alignment: .center)

                            Image("HoursLogo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: logoWidth, height: logoHeight)
                                .padding(.top, sharedLogoTopInset)
                        }
                        .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
                        .allowsHitTesting(false)
                        .onAppear {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                emptyStateQuoteProvider.randomizeQuote()
                            }
                        }
                        .overlay {
                            ShakeDetectorView {
                                changeQuote()
                            }
                            .allowsHitTesting(false)
                        }
                    } else {
                        CityListReorderUIKitView(
                            cities: $cityStore.cities,
                            selectedInstant: viewModel.selectedInstant,
                            userCurrentLocationItem: currentLocationProvider.currentCityItem,
                            cityViewPreference: selectedCityViewPreference,
                            // Keep scroll content layout independent from pinned button offset.
                            topSafeAreaInset: topButtonBarTopPadding + ((topButtonBarHeight - logoHeight) / 2),
                            // Desired visual stop gap from physical screen bottom.
                            bottomContentInset: cityListDesiredBottomGap,
                            cardBackgroundColor: SheetStyle.appCardBackground(for: theme),
                            onRenameRequested: presentRenameSheet(for:)
                        )
                        .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
                    }
                }
                .id(isCitiesEmpty ? "empty" : "list")
                .zIndex(isCitiesEmpty ? 1 : 0)

                ProgressiveBottomBlurOverlay(height: 180)
                    .allowsHitTesting(false)

                dialOverlay(in: geo)
                    // Measure the rendered dial overlay height and feed it into list bottom padding.
                    .background(
                        GeometryReader { proxy in
                            Color.clear
                                .preference(key: DialOverlayHeightPreferenceKey.self, value: proxy.size.height)
                        }
                    )

            }
            .overlay(alignment: .top) {
                topButtonBar()
                    .padding(.top, topControlsTop)
                    .ignoresSafeArea(edges: .top)
                    .zIndex(10)
            }
            .onPreferenceChange(DialOverlayHeightPreferenceKey.self) { measuredHeight in
                guard measuredHeight > 0 else { return }
                dialHeight = measuredHeight
            }
            .onAppear {
                prepareDialHaptics()
                resetNotificationHaptics.prepare()
                lastSnappedOffsetSteps = viewModel.dialSteps
                currentLocationProvider.requestCurrentCity()
            }
            .onChange(of: viewModel.dialSteps) { _, newStep in
                guard newStep != lastSnappedOffsetSteps else { return }
                let tickType: String
                if newStep == 0 {
                    tickType = "zero"
                } else if abs(newStep).isMultiple(of: 12) {
                    tickType = "big"
                } else {
                    tickType = "small"
                }
                log(
                    "[DIAL] snappedStep \(lastSnappedOffsetSteps) -> \(newStep) " +
                    "kind=\(tickType)"
                )
                fireHapticForSnappedStep(newStep)
                lastSnappedOffsetSteps = newStep
            }
        }
        .id("\(cityStore.cities.isEmpty ? "empty" : "list")-\(colorScheme == .dark ? "dark" : "light")")
        .ignoresSafeArea()
        .sheet(isPresented: $isAddCitySheetPresented, onDismiss: {
            if let pendingItem = pendingAddedCityItem {
                pendingAddedCityItem = nil
                DispatchQueue.main.async {
                    appendCityIfNeeded(pendingItem)
                }
            }
            currentLocationProvider.requestCurrentCity()
        }) {
            AddCitySheetView(
                existingCanonicalIDs: Set(cityStore.cities.map(\.id))
            ) { selectedItem in
                pendingAddedCityItem = selectedItem
            }
        }
        .sheet(isPresented: $isSettingsSheetPresented) {
            SettingsSheetView()
        }
        .sheet(item: $cityBeingRenamed) { city in
            ChangeCityNameSheetView(city: city) { customName in
                applyCustomDisplayName(customName, toCityID: city.id)
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                currentLocationProvider.requestCurrentCity()
            }
        }
    }

    private func topButtonBar() -> some View {
        GlassEffectContainer(spacing: 10) {
            HStack {
                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    isAddCitySheetPresented = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.capsule.fill")
                            .font(.system(size: 16, weight: .medium))
                        Text("Add")
                            .font(.system(size: 16, weight: .medium))
                            .tracking(-0.64)
                    }
                    .foregroundStyle(theme.textPrimary.opacity(0.90))
                    .frame(width: 87, height: topButtonBarHeight)
                    .modifier(TopControlGlassModifier(shape: Capsule()))
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)

                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    isSettingsSheetPresented = true
                }) {
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(theme.textPrimary.opacity(0.90))
                        .frame(width: topButtonBarHeight, height: topButtonBarHeight)
                        .modifier(TopControlGlassModifier(shape: Circle()))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
        }
    }

    private struct TopControlGlassModifier<S: Shape>: ViewModifier {
        let shape: S

        func body(content: Content) -> some View {
            content
                .contentShape(shape)
                .glassEffect(.regular, in: shape)
        }
    }

    private func dialOverlay(in geo: GeometryProxy) -> some View {
        ZStack(alignment: .bottom) {
            TimeDialView(
                diameter: dialSize,
                rotationDegrees: viewModel.rotationDegrees,
                stepIndex: viewModel.dialSteps,
                resetSignal: viewModel.resetSignal,
                onDragBegan: {
                    guard !isDraggingSessionActive else { return }
                    isDraggingSessionActive = true
                    viewModel.beginDialDrag()
                    prepareDialHaptics()
                    log("[DIAL] drag begin")
                },
                onDragChanged: { rotation in
                    viewModel.updateDialRotation(rotation)
                },
                onDragEnded: { currentRotation, predictedRotation in
                    if isDraggingSessionActive {
                        log("[DIAL] drag end")
                    }
                    isDraggingSessionActive = false
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

        if abs(offsetSteps).isMultiple(of: 12) {
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

    private func resolvedTopSafeAreaInset(from geometry: GeometryProxy) -> CGFloat {
        max(geometry.safeAreaInsets.top, Self.keyWindowTopSafeAreaInset())
    }

    private static func keyWindowTopSafeAreaInset() -> CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .safeAreaInsets.top ?? 0
    }

    private func log(_ message: String) {
        #if DEBUG
        print(message)
        #endif
    }

    private func appendCityIfNeeded(_ selectedItem: CitySearchItem) {
        let alreadyExists = cityStore.cities.contains(where: { $0.id == selectedItem.canonicalIdentity })
        guard !alreadyExists else {
            return
        }

        cityStore.cities.append(selectedItem.asCity)
    }

    private func presentRenameSheet(for city: City) {
        cityBeingRenamed = city
    }

    private func applyCustomDisplayName(_ customName: String?, toCityID cityID: City.ID) {
        guard let index = cityStore.cities.firstIndex(where: { $0.id == cityID }) else { return }
        cityStore.cities[index].customDisplayName = customName
    }

    private func changeQuote() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        withAnimation(.easeInOut(duration: 0.25)) {
            emptyStateQuoteProvider.randomizeQuote()
        }
    }
}

private struct DialOverlayHeightPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct ShakeDetectorView: UIViewRepresentable {
    var onShake: () -> Void

    func makeUIView(context: Context) -> ShakeDetector {
        let view = ShakeDetector()
        view.onShake = onShake
        return view
    }

    func updateUIView(_ uiView: ShakeDetector, context: Context) {
        uiView.onShake = onShake
    }
}

private final class ShakeDetector: UIView {
    var onShake: (() -> Void)?

    override var canBecomeFirstResponder: Bool { true }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        becomeFirstResponder()
    }

    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        guard motion == .motionShake else { return }
        onShake?()
    }
}

private struct CityListReorderUIKitView: UIViewControllerRepresentable {
    @Binding var cities: [City]
    let selectedInstant: Date
    let userCurrentLocationItem: CitySearchItem?
    let cityViewPreference: CityViewPreference
    let topSafeAreaInset: CGFloat
    let bottomContentInset: CGFloat
    let cardBackgroundColor: Color
    let onRenameRequested: (City) -> Void

    final class Coordinator {
        var parent: CityListReorderUIKitView

        init(parent: CityListReorderUIKitView) {
            self.parent = parent
        }

        func publishCities(_ cities: [City]) {
            DispatchQueue.main.async {
                self.parent.cities = cities
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> CityListReorderViewController {
        let controller = CityListReorderViewController()
        controller.onCitiesChanged = { [weak coordinator = context.coordinator] updatedCities in
            coordinator?.publishCities(updatedCities)
        }
        controller.onRenameRequested = { [weak coordinator = context.coordinator] city in
            coordinator?.parent.onRenameRequested(city)
        }
        controller.apply(
            cities: cities,
            selectedInstant: selectedInstant,
            userCurrentLocationItem: userCurrentLocationItem,
            cityViewPreference: cityViewPreference,
            topInset: topSafeAreaInset,
            bottomInset: bottomContentInset,
            cardBackgroundColor: cardBackgroundColor
        )
        return controller
    }

    func updateUIViewController(_ uiViewController: CityListReorderViewController, context: Context) {
        context.coordinator.parent = self
        uiViewController.onCitiesChanged = { [weak coordinator = context.coordinator] updatedCities in
            coordinator?.publishCities(updatedCities)
        }
        uiViewController.onRenameRequested = { [weak coordinator = context.coordinator] city in
            coordinator?.parent.onRenameRequested(city)
        }
        uiViewController.apply(
            cities: cities,
            selectedInstant: selectedInstant,
            userCurrentLocationItem: userCurrentLocationItem,
            cityViewPreference: cityViewPreference,
            topInset: topSafeAreaInset,
            bottomInset: bottomContentInset,
            cardBackgroundColor: cardBackgroundColor
        )
    }
}

private final class CityListReorderViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    private static var didPrintBottomInsetProbe = false
    private static let logoHeaderReuseIdentifier = "CityListLogoHeaderView"
    private static let logoHeight: CGFloat = 15
    private static let logoWidth: CGFloat = 49
    private static let logoBottomSpacing: CGFloat = 33

    private struct PendingExternalState {
        let cities: [City]
        let selectedInstant: Date
        let userCurrentLocationItem: CitySearchItem?
        let cityViewPreference: CityViewPreference
        let topInset: CGFloat
        let bottomInset: CGFloat
        let cardBackgroundColor: Color
    }

    var onCitiesChanged: (([City]) -> Void)?
    var onRenameRequested: ((City) -> Void)?

    private lazy var collectionViewLayout: UICollectionViewCompositionalLayout = {
        var listConfiguration = UICollectionLayoutListConfiguration(appearance: .plain)
        listConfiguration.showsSeparators = false
        listConfiguration.headerMode = .supplementary
        listConfiguration.headerTopPadding = 0
        listConfiguration.backgroundColor = .clear
        listConfiguration.trailingSwipeActionsConfigurationProvider = { [weak self] indexPath in
            self?.trailingSwipeActionsConfiguration(for: indexPath)
        }

        return UICollectionViewCompositionalLayout { _, layoutEnvironment in
            let section = NSCollectionLayoutSection.list(
                using: listConfiguration,
                layoutEnvironment: layoutEnvironment
            )
            section.interGroupSpacing = 8
            section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8)
            return section
        }
    }()
    private lazy var collectionView: UICollectionView = {
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: collectionViewLayout)
        collectionView.backgroundColor = .clear
        collectionView.showsVerticalScrollIndicator = false
        collectionView.alwaysBounceVertical = true
        collectionView.dragInteractionEnabled = false
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(
            CityListReorderCollectionCell.self,
            forCellWithReuseIdentifier: CityListReorderCollectionCell.reuseIdentifier
        )
        collectionView.register(
            CityListLogoHeaderView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: Self.logoHeaderReuseIdentifier
        )
        return collectionView
    }()

    private lazy var longPressGestureRecognizer: UILongPressGestureRecognizer = {
        let recognizer = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        recognizer.minimumPressDuration = 0.3
        recognizer.cancelsTouchesInView = false
        return recognizer
    }()

    private var citiesLocal: [City] = []
    private var selectedInstant: Date = Date()
    private var topInset: CGFloat = 0
    private var bottomInset: CGFloat = 0
    private var userCurrentLocationItem: CitySearchItem?
    private var cityViewPreference: CityViewPreference = .basic
    private var cardBackgroundColor: Color = AppTheme.light.surfaceCard
    private var isReordering = false
    private var pendingExternalState: PendingExternalState?
    private var needsPostAttachReload = false
    private var draggedCityID: City.ID?
    private weak var liftedCell: CityListReorderCollectionCell?
    private let deleteSuccessHaptics = UINotificationFeedbackGenerator()

    private var resolvedTheme: AppTheme {
        let colorScheme: ColorScheme = traitCollection.userInterfaceStyle == .dark ? .dark : .light
        return AppTheme.forColorScheme(colorScheme)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .clear
        view.addSubview(collectionView)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        collectionView.addGestureRecognizer(longPressGestureRecognizer)
        applySectionInsets()
        deleteSuccessHaptics.prepare()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        applySectionInsets()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        runPostAttachReloadIfNeeded()
    }

    func apply(
        cities: [City],
        selectedInstant: Date,
        userCurrentLocationItem: CitySearchItem?,
        cityViewPreference: CityViewPreference,
        topInset: CGFloat,
        bottomInset: CGFloat,
        cardBackgroundColor: Color
    ) {
        if isReordering {
            pendingExternalState = PendingExternalState(
                cities: cities,
                selectedInstant: selectedInstant,
                userCurrentLocationItem: userCurrentLocationItem,
                cityViewPreference: cityViewPreference,
                topInset: topInset,
                bottomInset: bottomInset,
                cardBackgroundColor: cardBackgroundColor
            )
            return
        }

        self.selectedInstant = selectedInstant
        self.cardBackgroundColor = cardBackgroundColor
        let didCurrentLocationChange = self.userCurrentLocationItem != userCurrentLocationItem
        self.userCurrentLocationItem = userCurrentLocationItem
        let didCityViewPreferenceChange = self.cityViewPreference != cityViewPreference
        self.cityViewPreference = cityViewPreference

        let insetsChanged = self.topInset != topInset || self.bottomInset != bottomInset
        if insetsChanged {
            self.topInset = topInset
            self.bottomInset = bottomInset
            applySectionInsets()
            collectionView.collectionViewLayout.invalidateLayout()
        }

        if cities.isEmpty && needsPostAttachReload {
            needsPostAttachReload = false
        }

        if cities.count > 0, !isRenderReadyForNonEmptyReload {
            needsPostAttachReload = true
        }

        if citiesLocal != cities {
            citiesLocal = cities
            collectionView.reloadData()
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.collectionView.layoutIfNeeded()
            }
            return
        }

        if didCurrentLocationChange {
            collectionView.reloadData()
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.collectionView.layoutIfNeeded()
            }
            return
        }

        if didCityViewPreferenceChange {
            collectionView.collectionViewLayout.invalidateLayout()
            collectionView.reloadData()
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.collectionView.layoutIfNeeded()
            }
            return
        }

        reconfigureVisibleCells()
    }

    private func applySectionInsets() {
        applyDeterministicBottomInset()
    }

    private func applyDeterministicBottomInset() {
        let desiredGap = bottomInset
        let safeBottom = collectionView.safeAreaInsets.bottom
        // Keep UIKit automatic safe-area adjustment enabled, so adjusted bottom becomes:
        // adjusted = contentInset.bottom + safeBottom ~= desiredGap (130pt target).
        let targetContentInsetBottom = max(0, desiredGap - safeBottom)
        let epsilon: CGFloat = 0.5

        if abs(collectionView.contentInset.bottom - targetContentInsetBottom) > epsilon {
            collectionView.contentInset = UIEdgeInsets(
                top: collectionView.contentInset.top,
                left: collectionView.contentInset.left,
                bottom: targetContentInsetBottom,
                right: collectionView.contentInset.right
            )
        }
        if abs(collectionView.verticalScrollIndicatorInsets.bottom - targetContentInsetBottom) > epsilon {
            collectionView.verticalScrollIndicatorInsets = UIEdgeInsets(
                top: collectionView.verticalScrollIndicatorInsets.top,
                left: collectionView.verticalScrollIndicatorInsets.left,
                bottom: targetContentInsetBottom,
                right: collectionView.verticalScrollIndicatorInsets.right
            )
        }

        #if DEBUG
        if !Self.didPrintBottomInsetProbe {
            print(
                "[SCROLLPROBE] desiredGap=\(desiredGap) safeBottom=\(safeBottom) " +
                "contentInsetBottom=\(collectionView.contentInset.bottom) " +
                "adjustedInsetBottom=\(collectionView.adjustedContentInset.bottom)"
            )
            Self.didPrintBottomInsetProbe = true
        }
        #endif
    }

    private var isRenderReadyForNonEmptyReload: Bool {
        let hasNonZeroBounds = collectionView.bounds.width > 0 && collectionView.bounds.height > 0
        return view.window != nil && hasNonZeroBounds
    }

    private func runPostAttachReloadIfNeeded() {
        guard needsPostAttachReload else { return }
        guard !citiesLocal.isEmpty else { return }
        guard isRenderReadyForNonEmptyReload else { return }

        collectionView.collectionViewLayout.invalidateLayout()
        collectionView.reloadData()
        collectionView.layoutIfNeeded()
        needsPostAttachReload = false
    }

    private func reconfigureVisibleCells() {
        let matchedCurrentLocationIndex = currentLocationMatchIndex()

        for indexPath in collectionView.indexPathsForVisibleItems {
            guard indexPath.item < citiesLocal.count else { continue }
            guard let cell = collectionView.cellForItem(at: indexPath) as? CityListReorderCollectionCell else { continue }

            let city = citiesLocal[indexPath.item]
            let referenceTimeZone = citiesLocal.first?.timeZone ?? city.timeZone
            cell.configure(
                city: city,
                selectedInstant: selectedInstant,
                referenceTimeZone: referenceTimeZone,
                isCurrent: indexPath.item == 0,
                isUserCurrentLocation: matchedCurrentLocationIndex == indexPath.item,
                cityViewPreference: cityViewPreference,
                cardBackgroundColor: cardBackgroundColor
            )
        }
    }

    private func currentLocationMatchIndex() -> Int? {
        guard let userCurrentLocationItem else { return nil }
        guard !citiesLocal.isEmpty else { return nil }

        let currentCanonicalID = userCurrentLocationItem.canonicalIdentity
        let normalizedCurrentCity = normalized(userCurrentLocationItem.city)
        let currentTimeZoneID = userCurrentLocationItem.timeZoneIdentifier.lowercased()

        if let canonicalMatchIndex = citiesLocal.firstIndex(where: {
            !$0.isZeroOffsetReferenceCity &&
            $0.id == currentCanonicalID
        }) {
            return canonicalMatchIndex
        }

        if let exactMatchIndex = citiesLocal.firstIndex(where: {
            !$0.isZeroOffsetReferenceCity &&
            $0.timeZoneID.lowercased() == currentTimeZoneID &&
            normalized($0.name) == normalizedCurrentCity
        }) {
            return exactMatchIndex
        }

        let timeZoneMatchIndices = citiesLocal.indices.filter { index in
            let city = citiesLocal[index]
            return !city.isZeroOffsetReferenceCity &&
                city.timeZoneID.lowercased() == currentTimeZoneID
        }
        if timeZoneMatchIndices.count == 1, let onlyMatch = timeZoneMatchIndices.first {
            return onlyMatch
        }

        let cityNameMatchIndices = citiesLocal.indices.filter { index in
            let city = citiesLocal[index]
            return !city.isZeroOffsetReferenceCity &&
                normalized(city.name) == normalizedCurrentCity
        }
        if cityNameMatchIndices.count == 1, let onlyMatch = cityNameMatchIndices.first {
            return onlyMatch
        }

        return nil
    }

    private func normalized(_ input: String) -> String {
        input
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    @objc
    private func handleLongPress(_ recognizer: UILongPressGestureRecognizer) {
        let location = recognizer.location(in: collectionView)

        switch recognizer.state {
        case .began:
            guard let indexPath = collectionView.indexPathForItem(at: location) else { return }
            guard indexPath.item < citiesLocal.count else { return }
            guard collectionView.beginInteractiveMovementForItem(at: indexPath) else { return }

            isReordering = true
            draggedCityID = citiesLocal[indexPath.item].id
            if let cell = collectionView.cellForItem(at: indexPath) as? CityListReorderCollectionCell {
                liftedCell = cell
                cell.setLifted(true)
            }

        case .changed:
            guard isReordering else { return }
            var target = location
            target.x = collectionView.bounds.midX
            collectionView.updateInteractiveMovementTargetPosition(target)

        case .ended:
            guard isReordering else { return }
            collectionView.endInteractiveMovement()
            finishInteractiveMovement()

        case .cancelled, .failed:
            guard isReordering else { return }
            collectionView.cancelInteractiveMovement()
            finishInteractiveMovement()

        default:
            guard isReordering else { return }
            collectionView.cancelInteractiveMovement()
            finishInteractiveMovement()
        }
    }

    private func finishInteractiveMovement() {
        isReordering = false
        liftedCell?.setLifted(false)
        liftedCell = nil

        let draggedID = draggedCityID
        draggedCityID = nil

        #if DEBUG
        if let draggedID, let finalIndex = citiesLocal.firstIndex(where: { $0.id == draggedID }) {
            print("[REORDER_UIKIT] end finalIndex=\(finalIndex)")
        } else {
            print("[REORDER_UIKIT] end finalIndex=-1")
        }
        #endif

        applyPendingExternalStateIfNeeded()
    }

    private func applyPendingExternalStateIfNeeded() {
        guard let pendingExternalState else { return }
        self.pendingExternalState = nil
        apply(
            cities: pendingExternalState.cities,
            selectedInstant: pendingExternalState.selectedInstant,
            userCurrentLocationItem: pendingExternalState.userCurrentLocationItem,
            cityViewPreference: pendingExternalState.cityViewPreference,
            topInset: pendingExternalState.topInset,
            bottomInset: pendingExternalState.bottomInset,
            cardBackgroundColor: pendingExternalState.cardBackgroundColor
        )
    }

    private func trailingSwipeActionsConfiguration(for indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard !isReordering else { return nil }
        guard citiesLocal.indices.contains(indexPath.item) else { return nil }

        let renameAction = UIContextualAction(style: .normal, title: nil) { [weak self] _, _, completion in
            guard let self else {
                completion(false)
                return
            }
            guard self.citiesLocal.indices.contains(indexPath.item) else {
                completion(false)
                return
            }
            triggerRenameHaptics()
            let city = self.citiesLocal[indexPath.item]
            DispatchQueue.main.async {
                self.onRenameRequested?(city)
            }
            completion(true)
        }
        renameAction.image = UIImage(systemName: "character.textbox")?.withTintColor(
            UIColor(resolvedTheme.textInverse),
            renderingMode: .alwaysOriginal
        )
        renameAction.backgroundColor = UIColor(resolvedTheme.textPrimary)

        let deleteAction = UIContextualAction(style: .destructive, title: nil) { [weak self] _, _, completion in
            guard let self else {
                completion(false)
                return
            }
            completion(deleteCity(at: indexPath))
        }
        deleteAction.image = UIImage(systemName: "trash.fill")
        deleteAction.backgroundColor = UIColor(resolvedTheme.accent)

        // UIKit trailing actions render first item on the far trailing edge.
        // Order here yields: Rename (near card), Delete (far right).
        let configuration = UISwipeActionsConfiguration(actions: [deleteAction, renameAction])
        configuration.performsFirstActionWithFullSwipe = false
        return configuration
    }

    private func triggerRenameHaptics() {
        let fire = {
            let haptics = UIImpactFeedbackGenerator(style: .medium)
            haptics.impactOccurred()
        }

        if Thread.isMainThread {
            fire()
        } else {
            DispatchQueue.main.async(execute: fire)
        }
    }

    @discardableResult
    private func deleteCity(at indexPath: IndexPath) -> Bool {
        guard !isReordering else { return false }
        guard citiesLocal.indices.contains(indexPath.item) else { return false }

        citiesLocal.remove(at: indexPath.item)
        let updatedCities = citiesLocal

        collectionView.performBatchUpdates {
            collectionView.deleteItems(at: [indexPath])
        } completion: { [weak self] _ in
            self?.reconfigureVisibleCells()
        }

        deleteSuccessHaptics.notificationOccurred(.success)
        deleteSuccessHaptics.prepare()
        DispatchQueue.main.async { [weak self] in
            self?.onCitiesChanged?(updatedCities)
        }
        return true
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return citiesLocal.count
    }

    func collectionView(_ collectionView: UICollectionView, canMoveItemAt indexPath: IndexPath) -> Bool {
        indexPath.item < citiesLocal.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        moveItemAt sourceIndexPath: IndexPath,
        to destinationIndexPath: IndexPath
    ) {
        guard sourceIndexPath.item != destinationIndexPath.item else { return }
        guard
            citiesLocal.indices.contains(sourceIndexPath.item),
            destinationIndexPath.item >= 0,
            destinationIndexPath.item <= citiesLocal.count - 1
        else {
            return
        }

        let movedCity = citiesLocal.remove(at: sourceIndexPath.item)
        citiesLocal.insert(movedCity, at: destinationIndexPath.item)

        #if DEBUG
        print("[REORDER_UIKIT] move from=\(sourceIndexPath.item) to=\(destinationIndexPath.item)")
        #endif

        let updatedCities = citiesLocal
        DispatchQueue.main.async { [weak self] in
            self?.onCitiesChanged?(updatedCities)
        }
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        guard
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: CityListReorderCollectionCell.reuseIdentifier,
                for: indexPath
            ) as? CityListReorderCollectionCell
        else {
            return UICollectionViewCell()
        }

        guard indexPath.item < citiesLocal.count else { return cell }

        let city = citiesLocal[indexPath.item]
        let referenceTimeZone = citiesLocal.first?.timeZone ?? city.timeZone
        let matchedCurrentLocationIndex = currentLocationMatchIndex()
        cell.configure(
            city: city,
            selectedInstant: selectedInstant,
            referenceTimeZone: referenceTimeZone,
            isCurrent: indexPath.item == 0,
            isUserCurrentLocation: matchedCurrentLocationIndex == indexPath.item,
            cityViewPreference: cityViewPreference,
            cardBackgroundColor: cardBackgroundColor
        )
        return cell
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        let height: CGFloat = cityViewPreference == .compact ? 88 : 140
        return CGSize(width: max(0, collectionView.bounds.width - 32), height: height)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        minimumLineSpacingForSectionAt section: Int
    ) -> CGFloat {
        8
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        referenceSizeForHeaderInSection section: Int
    ) -> CGSize {
        CGSize(
            width: max(0, collectionView.bounds.width - 32),
            height: topInset + Self.logoHeight + Self.logoBottomSpacing
        )
    }

    func collectionView(
        _ collectionView: UICollectionView,
        viewForSupplementaryElementOfKind kind: String,
        at indexPath: IndexPath
    ) -> UICollectionReusableView {
        guard kind == UICollectionView.elementKindSectionHeader else {
            return UICollectionReusableView()
        }
        guard let header = collectionView.dequeueReusableSupplementaryView(
            ofKind: kind,
            withReuseIdentifier: Self.logoHeaderReuseIdentifier,
            for: indexPath
        ) as? CityListLogoHeaderView else {
            return UICollectionReusableView()
        }

        header.configure(
            topInset: topInset,
            logoHeight: Self.logoHeight,
            logoWidth: Self.logoWidth,
            logoBottomSpacing: Self.logoBottomSpacing
        )

        return header
    }
}

private extension City {
    var isZeroOffsetReferenceCity: Bool {
        let canonicalID = id.lowercased()
        if canonicalID == "custom.utc" || canonicalID == "custom.gmt" {
            return true
        }

        let timeZoneID = timeZoneID.lowercased()
        return timeZoneID == "etc/utc" || timeZoneID == "utc" || timeZoneID == "gmt"
    }
}

private final class CityListLogoHeaderView: UICollectionReusableView {
    private let imageView: UIImageView = {
        let imageView = UIImageView(image: UIImage(named: "HoursLogo"))
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = .clear
        imageView.isUserInteractionEnabled = false
        return imageView
    }()

    private var topConstraint: NSLayoutConstraint?
    private var heightConstraint: NSLayoutConstraint?
    private var widthConstraint: NSLayoutConstraint?
    private var bottomConstraint: NSLayoutConstraint?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        addSubview(imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = false

        let topConstraint = imageView.topAnchor.constraint(equalTo: topAnchor)
        let heightConstraint = imageView.heightAnchor.constraint(equalToConstant: 15)
        let widthConstraint = imageView.widthAnchor.constraint(equalToConstant: 49)
        let bottomConstraint = bottomAnchor.constraint(greaterThanOrEqualTo: imageView.bottomAnchor)
        NSLayoutConstraint.activate([
            topConstraint,
            heightConstraint,
            widthConstraint,
            bottomConstraint,
            imageView.centerXAnchor.constraint(equalTo: centerXAnchor)
        ])

        self.topConstraint = topConstraint
        self.heightConstraint = heightConstraint
        self.widthConstraint = widthConstraint
        self.bottomConstraint = bottomConstraint
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(topInset: CGFloat, logoHeight: CGFloat, logoWidth: CGFloat, logoBottomSpacing: CGFloat) {
        topConstraint?.constant = topInset
        heightConstraint?.constant = logoHeight
        widthConstraint?.constant = logoWidth
        bottomConstraint?.constant = logoBottomSpacing
    }
}

private final class CityListReorderCollectionCell: UICollectionViewCell {
    static let reuseIdentifier = "CityListReorderCollectionCell"

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        contentView.backgroundColor = .clear
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        setLifted(false, animated: false)
    }

    func configure(
        city: City,
        selectedInstant: Date,
        referenceTimeZone: TimeZone,
        isCurrent: Bool,
        isUserCurrentLocation: Bool,
        cityViewPreference: CityViewPreference,
        cardBackgroundColor: Color
    ) {
        let resolvedTheme = AppTheme.forColorScheme(traitCollection.userInterfaceStyle == .dark ? .dark : .light)
        contentConfiguration = UIHostingConfiguration {
            CityCardView(
                city: city,
                selectedInstant: selectedInstant,
                referenceTimeZone: referenceTimeZone,
                isCurrent: isCurrent,
                isUserCurrentLocation: isUserCurrentLocation,
                cityViewPreference: cityViewPreference,
                cardBackgroundColor: cardBackgroundColor
            )
            .environment(\.appTheme, resolvedTheme)
        }
        .margins(.all, 0)
    }

    func setLifted(_ lifted: Bool, animated: Bool = true) {
        let updates = {
            self.transform = lifted ? CGAffineTransform(scaleX: 1.03, y: 1.03) : .identity
            self.layer.shadowColor = UIColor.black.cgColor
            self.layer.shadowOpacity = lifted ? 0.18 : 0
            self.layer.shadowRadius = lifted ? 10 : 0
            self.layer.shadowOffset = lifted ? CGSize(width: 0, height: 6) : .zero
        }

        if animated {
            UIView.animate(
                withDuration: 0.16,
                delay: 0,
                options: [.beginFromCurrentState, .curveEaseOut],
                animations: updates
            )
        } else {
            updates()
        }
    }
}

struct CityListView: View {
    @Environment(\.appTheme) private var theme
    @Binding var cities: [City]
    let selectedInstant: Date
    let currentCity: City
    let topSafeAreaInset: CGFloat
    let bottomContentInset: CGFloat

    @StateObject private var reorderController = ReorderController()
    @StateObject private var scrollViewHolder = ScrollViewHolder()
    @State private var lastGlobalRowFrames: [City.ID: CGRect] = [:]
    @State private var lastGlobalRowFramesHash: Int = 0
    @State private var rowFrames: [City.ID: CGRect] = [:]
    @State private var pendingRowFrames: [City.ID: CGRect] = [:]
    @State private var rowFramesCommitScheduled = false
    @State private var activeRowFramesSnapshot: [City.ID: CGRect]?
    @State private var beginContentOffsetY: CGFloat = 0
    @State private var hasContentSpaceRowFrames = false
    @State private var lastRowFramesHash: Int = 0
    @State private var didLogReorderDataNotReady = false
    @State private var scrollViewport: CGRect = .zero
    @State private var lastContentProbeHeight: Int = -1
    @State private var lastViewportProbeHeight: Int = -1

    private let cardHeight: CGFloat = 140
    private let cardSpacing: CGFloat = 8
    private let horizontalPadding: CGFloat = 16
    private let reorderStartHaptics = UIImpactFeedbackGenerator(style: .light)
    private let reorderDropHaptics = UINotificationFeedbackGenerator()
    private let autoScrollTimer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { listGeo in
            ZStack(alignment: .topLeading) {
            ScrollView {
                LazyVStack(spacing: cardSpacing) {
                    ForEach(Array(cities.enumerated()), id: \.element.id) { index, city in
                        rowView(for: city, at: index)
                            .background(
                                GeometryReader { proxy in
                                    Color.clear.preference(
                                        key: CityRowFramePreferenceKey.self,
                                        value: [city.id: proxy.frame(in: .global)]
                                    )
                                }
                            )
                            .offset(y: reorderController.rowOffset(for: index, rowStride: cardHeight + cardSpacing))
                    }
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.top, topSafeAreaInset)
                .padding(.bottom, bottomContentInset)
                .animation(.interactiveSpring(response: 0.28, dampingFraction: 0.86), value: reorderController.proposedIndex)
                .animation(.interactiveSpring(response: 0.28, dampingFraction: 0.86), value: cities)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .scrollIndicators(.hidden)
            .background(ScrollViewIntrospector { scrollView in
                let holder = scrollViewHolder
                DispatchQueue.main.async { [weak holder] in
                    guard let holder else { return }
                    let didCapture = holder.setIfChanged(scrollView)
                    if ENABLE_SCROLL_PROBE, didCapture {
                        print("[SCROLLPROBE] found scroll view class=\(type(of: scrollView))")
                        print(
                            "[SCROLLPROBE] injected UIScrollView captured: \(ObjectIdentifier(scrollView)) " +
                            "viewportHeight=\(Int(scrollView.bounds.height.rounded())) " +
                            "frame=\(scrollView.frame) contentSize=\(scrollView.contentSize) " +
                            "offset=\(scrollView.contentOffset)"
                        )
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            print(
                                "[SCROLLPROBE] injected UIScrollView post-layout: \(ObjectIdentifier(scrollView)) " +
                                "viewportHeight=\(Int(scrollView.bounds.height.rounded())) " +
                                "frame=\(scrollView.frame) contentSize=\(scrollView.contentSize) " +
                                "offset=\(scrollView.contentOffset)"
                            )
                        }
                    }
                    reorderController.attachScrollView(scrollView)
                }
            })

            if let draggedCity = draggedCity,
               let initialFrame = reorderController.dragInitialFrame {
                let contentOffset = scrollViewHolder.scrollView?.contentOffset ?? .zero
                CityCardView(
                    city: draggedCity,
                    selectedInstant: selectedInstant,
                    referenceTimeZone: currentCity.timeZone,
                    isCurrent: (reorderController.proposedIndex ?? reorderController.sourceIndex ?? 0) == 0,
                    cardBackgroundColor: SheetStyle.appCardBackground(for: theme)
                )
                .frame(width: initialFrame.width, height: initialFrame.height)
                .scaleEffect(1.03)
                .shadow(color: .black.opacity(0.20), radius: 18, y: 12)
                .position(
                    x: initialFrame.midX - contentOffset.x,
                    y: (initialFrame.midY + reorderController.dragTranslationY) - contentOffset.y
                )
                .zIndex(10_000)
                .allowsHitTesting(reorderController.isReordering)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onPreferenceChange(CityRowFramePreferenceKey.self) { frames in
            guard !reorderController.isReordering else { return }
            guard let scrollView = scrollViewHolder.scrollView else { return }
            let globalHash = rowFramesHash(frames)
            DispatchQueue.main.async {
                if globalHash != self.lastGlobalRowFramesHash {
                    self.lastGlobalRowFramesHash = globalHash
                    self.lastGlobalRowFrames = frames
                }
                let recalcConverted = convertGlobalFramesToContentSpace(self.lastGlobalRowFrames, scrollView: scrollView)
                scheduleRowFramesCommit(recalcConverted)

                if ENABLE_SCROLL_PROBE {
                    let metrics = reorderController.scrollMetrics()
                    let contentHeight = metrics?.contentHeight
                        ?? (max(0, (recalcConverted.values.map(\.maxY).max() ?? 0) - (recalcConverted.values.map(\.minY).min() ?? 0))
                            + topSafeAreaInset + bottomContentInset)
                    let roundedContentHeight = Int(contentHeight.rounded())
                    if roundedContentHeight != self.lastContentProbeHeight {
                        self.lastContentProbeHeight = roundedContentHeight
                        print(
                            "[SCROLLPROBE] contentHeight=\(roundedContentHeight) " +
                            "viewportHeight=\(Int((metrics?.viewportHeight ?? scrollViewport.height).rounded()))"
                        )
                    }
                }
            }
        }
        .onReceive(scrollViewHolder.$scrollView) { scrollView in
            guard let scrollView else { return }
            DispatchQueue.main.async {
                guard !self.reorderController.isReordering else { return }
                let converted = convertGlobalFramesToContentSpace(self.lastGlobalRowFrames, scrollView: scrollView)
                scheduleRowFramesCommit(converted)
            }
        }
        .onChange(of: listGeo.size) { _, newSize in
            scrollViewport = CGRect(origin: .zero, size: newSize)
            if ENABLE_SCROLL_PROBE {
                let roundedViewportHeight = Int(newSize.height.rounded())
                if roundedViewportHeight != lastViewportProbeHeight {
                    lastViewportProbeHeight = roundedViewportHeight
                    print("[SCROLLPROBE] viewportHeight=\(roundedViewportHeight)")
                }
            }
        }
        .onReceive(autoScrollTimer) { _ in
            guard reorderController.isReordering else { return }
            if reorderController.stepAutoScroll(viewport: scrollViewport) {
                reorderController.refreshProposedIndex(cityOrder: cities, rowFrames: effectiveRowFramesForReorder)
            }
        }
        .onChange(of: reorderController.isReordering) { _, isReordering in
            DispatchQueue.main.async {
                reorderController.setScrollDisabled(isReordering)
            }
            if !isReordering {
                activeRowFramesSnapshot = nil
                beginContentOffsetY = 0
                if let scrollView = scrollViewHolder.scrollView {
                    let converted = convertGlobalFramesToContentSpace(lastGlobalRowFrames, scrollView: scrollView)
                    DispatchQueue.main.async {
                        scheduleRowFramesCommit(converted)
                    }
                }
            }
            cityListDebugLog("scrollDisabled=\(isReordering)")
            if ENABLE_SCROLL_PROBE {
                if let metrics = reorderController.scrollMetrics() {
                    print("[SCROLL] native isScrollEnabled = \(metrics.isScrollEnabled)")
                }
                print("[SCROLL] scrollDisabled = \(isReordering)")
                print("[PROBE] Overlay allowsHitTesting = \(isReordering)")
            }
        }
        .onAppear {
            reorderStartHaptics.prepare()
            reorderDropHaptics.prepare()
            scrollViewport = CGRect(origin: .zero, size: listGeo.size)
            if ENABLE_SCROLL_PROBE {
                print("[PROBE] CityList appeared")
                if let metrics = reorderController.scrollMetrics() {
                    print(
                        "[SCROLLPROBE] initial offset=\(Int(metrics.offsetY.rounded())) " +
                        "contentHeight=\(Int(metrics.contentHeight.rounded())) " +
                        "viewportHeight=\(Int(metrics.viewportHeight.rounded()))"
                    )
                }
            }
        }
        .onDisappear {
            reorderController.cancel(reason: "view-disappear")
        }
        // === SCROLL PROBE DEBUG ===
        .overlay {
            if ENABLE_SCROLL_PROBE {
                HitTestProbeView(
                    tag: "CityListRoot",
                    isReordering: reorderController.isReordering,
                    overlayHitTesting: reorderController.isReordering && draggedCity != nil
                )
            }
        }
        }
    }

    @ViewBuilder
    private func rowView(for city: City, at index: Int) -> some View {
        let isDraggedRow = reorderController.draggedCityID == city.id
        let longPressEnabled = !DISABLE_REORDER && (!reorderController.isReordering || isDraggedRow)

        CityCardView(
            city: city,
            selectedInstant: selectedInstant,
            referenceTimeZone: currentCity.timeZone,
            isCurrent: index == 0,
            cardBackgroundColor: SheetStyle.appCardBackground(for: theme)
        )
        // Keep layout stable while this row is represented by the top-level dragged overlay.
        .opacity(isDraggedRow ? 0 : 1)
        .contentShape(Rectangle())
        .modifier(RowLongPressDriverModifier(
            enabled: longPressEnabled,
            scrollView: scrollViewHolder.scrollView,
            onBegan: { touchYContent, contentOffsetY in
                cityListDebugLog("REORDER longPress complete sourceIndex=\(index) city=\(city.id)")
                beginReorderIfPossible(
                    for: city,
                    at: index,
                    touchYContent: touchYContent,
                    contentOffsetY: contentOffsetY
                )
            },
            onChanged: { translationY in
                guard reorderController.isReordering, reorderController.draggedCityID == city.id else { return }
                reorderController.updateDrag(
                    translationY: translationY,
                    cityOrder: cities,
                    rowFrames: effectiveRowFramesForReorder
                )
            },
            onEnded: {
                guard reorderController.isReordering, reorderController.draggedCityID == city.id else { return }
                #if DEBUG
                if ENABLE_SCROLL_PROBE {
                    let source = reorderController.sourceIndex ?? -1
                    let destination = reorderController.proposedIndex ?? source
                    let finalOffsetY = scrollViewHolder.scrollView?.contentOffset.y ?? beginContentOffsetY
                    let overlayCenterYContent = (reorderController.dragInitialFrame?.midY ?? 0) + reorderController.dragTranslationY
                    print(
                        "[REORDER_END] source=\(source) dest=\(destination) finalOffsetY=\(finalOffsetY) " +
                        "overlayCenterYContent=\(overlayCenterYContent)"
                    )
                }
                #endif
                let moved = reorderController.commitReorder(cities: &cities)
                if moved {
                    reorderDropHaptics.notificationOccurred(.success)
                    reorderDropHaptics.prepare()
                }
            },
            onCancelled: {
                guard reorderController.isReordering, reorderController.draggedCityID == city.id else { return }
                reorderController.cancel(reason: "long-press-cancelled")
            }
        ))
    }

    private var draggedCity: City? {
        guard let draggedCityID = reorderController.draggedCityID else { return nil }
        return cities.first(where: { $0.id == draggedCityID })
    }

    private func beginReorderIfPossible(
        for city: City,
        at index: Int,
        touchYContent: CGFloat,
        contentOffsetY: CGFloat
    ) {
        guard scrollViewHolder.scrollView != nil, hasContentSpaceRowFrames else {
            #if DEBUG
            if ENABLE_SCROLL_PROBE, !didLogReorderDataNotReady {
                print("[REORDER] abort begin: scrollView or content-space rowFrames not ready")
                didLogReorderDataNotReady = true
            }
            #endif
            return
        }

        let snapshotFrames = rowFrames.isEmpty ? pendingRowFrames : rowFrames
        guard let sourceFrame = snapshotFrames[city.id] else {
            #if DEBUG
            if ENABLE_SCROLL_PROBE, !didLogReorderDataNotReady {
                print("[REORDER] abort begin: missing row frame for \(city.id) (rowFrames not ready)")
                didLogReorderDataNotReady = true
            }
            #endif
            return
        }

        #if DEBUG
        if ENABLE_SCROLL_PROBE {
            let rowMinY = sourceFrame.minY
            let rowMaxY = sourceFrame.maxY
            let touchInRow = touchYContent >= rowMinY && touchYContent <= rowMaxY
            let offsetY = scrollViewHolder.scrollView?.contentOffset.y ?? contentOffsetY
            print(
                "[REORDER_BEGIN] idx=\(index) offsetY=\(offsetY) " +
                "touchYContent=\(touchYContent) row=[\(rowMinY),\(rowMaxY)] " +
                "touchInRow=\(touchInRow) framesCount=\(snapshotFrames.count)"
            )
            print(
                "[REORDER_BEGIN] sourceFrameContent=\(sourceFrame) " +
                "overlayInitialCenterContent=\(sourceFrame.midY)"
            )
        }
        #endif

        let started = reorderController.beginIfNeeded(
            cityID: city.id,
            sourceIndex: index,
            startFrame: sourceFrame
        )
        guard started else { return }
        activeRowFramesSnapshot = snapshotFrames
        beginContentOffsetY = contentOffsetY
        reorderStartHaptics.impactOccurred()
        reorderStartHaptics.prepare()
    }

    private func convertGlobalFramesToContentSpace(
        _ globalFrames: [City.ID: CGRect],
        scrollView: UIScrollView
    ) -> [City.ID: CGRect] {
        return globalFrames.reduce(into: [City.ID: CGRect]()) { result, entry in
            let id = entry.key
            let global = entry.value
            result[id] = rectInContentSpace(globalRect: global, scrollView: scrollView)
        }
    }

    private func rectInContentSpace(globalRect: CGRect, scrollView: UIScrollView) -> CGRect {
        let boundsRect = scrollView.convert(globalRect, from: nil)
        return boundsRect.offsetBy(dx: scrollView.contentOffset.x, dy: scrollView.contentOffset.y)
    }

    private func applyConvertedRowFramesIfNeeded(_ converted: [City.ID: CGRect]) {
        let newHash = rowFramesHash(converted)
        guard newHash != lastRowFramesHash else { return }
        rowFrames = converted
        lastRowFramesHash = newHash
        hasContentSpaceRowFrames = !converted.isEmpty
        if hasContentSpaceRowFrames {
            didLogReorderDataNotReady = false
        }
        reorderController.refreshProposedIndex(cityOrder: cities, rowFrames: converted)
    }

    private func scheduleRowFramesCommit(_ newFrames: [City.ID: CGRect]) {
        pendingRowFrames = newFrames
        guard !rowFramesCommitScheduled else { return }
        rowFramesCommitScheduled = true

        DispatchQueue.main.async {
            self.rowFramesCommitScheduled = false
            guard !self.reorderController.isReordering else { return }
            self.applyConvertedRowFramesIfNeeded(self.pendingRowFrames)
        }
    }

    private func rowFramesHash(_ frames: [City.ID: CGRect]) -> Int {
        var hasher = Hasher()
        hasher.combine(frames.count)
        for (id, rect) in frames.sorted(by: { String(describing: $0.key) < String(describing: $1.key) }) {
            hasher.combine(id)
            hasher.combine(Int(rect.minX.rounded()))
            hasher.combine(Int(rect.minY.rounded()))
            hasher.combine(Int(rect.width.rounded()))
            hasher.combine(Int(rect.height.rounded()))
        }
        return hasher.finalize()
    }

    private var effectiveRowFramesForReorder: [City.ID: CGRect] {
        if reorderController.isReordering, let snapshot = activeRowFramesSnapshot {
            return snapshot
        }
        return rowFrames
    }
}

@MainActor
final class ReorderController: NSObject, ObservableObject {
    @Published private(set) var isReordering = false
    @Published private(set) var draggedCityID: City.ID?
    @Published private(set) var sourceIndex: Int?
    @Published private(set) var proposedIndex: Int?
    @Published private(set) var dragInitialFrame: CGRect?
    @Published private(set) var dragTranslationY: CGFloat = 0

    private weak var scrollView: UIScrollView?
    private var scrollBoundsObservation: NSKeyValueObservation?
    private var scrollContentSizeObservation: NSKeyValueObservation?
    private var scrollContentOffsetObservation: NSKeyValueObservation?
    private var isScrollDisabled = false
    private var lastAutoScrollLogTimestamp: CFTimeInterval = 0
    private var lastDragLogTimestamp: CFTimeInterval = 0
    private var lastScrollProbeOffsetLogTimestamp: CFTimeInterval = 0

    var attachedScrollView: UIScrollView? {
        scrollView
    }

    func attachScrollView(_ scrollView: UIScrollView) {
        let isNewScrollView = self.scrollView !== scrollView
        if isNewScrollView {
            stopObservingScrollView()
            self.scrollView = scrollView
            startObservingScrollView(scrollView)
            cityListDebugLog(
                "scrollView attached offset=\(scrollView.contentOffset.y) " +
                "content=\(scrollView.contentSize.height) bounds=\(scrollView.bounds.height)"
            )
        }
        applyScrollEnabledState()
        if ENABLE_SCROLL_PROBE {
            DispatchQueue.main.async { [weak self] in
                guard let self, let metrics = self.scrollMetrics() else { return }
                print(
                    "[SCROLLPROBE] attached offset=\(Int(metrics.offsetY.rounded())) " +
                    "contentHeight=\(Int(metrics.contentHeight.rounded())) " +
                    "viewportHeight=\(Int(metrics.viewportHeight.rounded())) " +
                    "isScrollEnabled=\(metrics.isScrollEnabled)"
                )
            }
        }
    }

    func setScrollDisabled(_ disabled: Bool) {
        isScrollDisabled = disabled
        applyScrollEnabledState()
    }

    func scrollMetrics() -> (
        offsetY: CGFloat,
        contentHeight: CGFloat,
        viewportHeight: CGFloat,
        isScrollEnabled: Bool
    )? {
        guard let scrollView else { return nil }
        return (
            offsetY: scrollView.contentOffset.y,
            contentHeight: scrollView.contentSize.height,
            viewportHeight: scrollView.bounds.height,
            isScrollEnabled: scrollView.isScrollEnabled
        )
    }

    func currentContentOffset() -> CGPoint {
        scrollView?.contentOffset ?? .zero
    }

    func beginIfNeeded(cityID: City.ID, sourceIndex: Int, startFrame: CGRect?) -> Bool {
        guard draggedCityID == nil else { return false }
        guard let startFrame else {
            cityListDebugLog("drag begin blocked: missing row frame for \(cityID)")
            return false
        }
        cityListDebugLog("isReordering -> true")
        isReordering = true
        setScrollDisabled(true)
        draggedCityID = cityID
        self.sourceIndex = sourceIndex
        proposedIndex = sourceIndex
        dragInitialFrame = startFrame
        dragTranslationY = 0
        cityListDebugLog("REORDER drag begin city=\(cityID) sourceIndex=\(sourceIndex)")
        return true
    }

    func updateDrag(
        translationY: CGFloat,
        cityOrder: [City],
        rowFrames: [City.ID: CGRect]
    ) {
        guard sourceIndex != nil, draggedCityID != nil else { return }
        dragTranslationY = translationY
        let now = CACurrentMediaTime()
        if now - lastDragLogTimestamp > 0.20 {
            cityListDebugLog("REORDER drag changed y=\(Int(translationY.rounded()))")
            lastDragLogTimestamp = now
        }
        refreshProposedIndex(cityOrder: cityOrder, rowFrames: rowFrames)
    }

    func refreshProposedIndex(cityOrder: [City], rowFrames: [City.ID: CGRect]) {
        guard let overlayCenterY = overlayCenterY else { return }
        let newIndex = calculatedDestinationIndex(
            cityOrder: cityOrder,
            rowFrames: rowFrames,
            overlayCenterY: overlayCenterY
        )
        guard newIndex != proposedIndex else { return }
        proposedIndex = newIndex
        cityListDebugLog("proposedIndex=\(newIndex)")
    }

    func stepAutoScroll(viewport: CGRect) -> Bool {
        guard
            isReordering,
            let scrollView,
            viewport.height > 0,
            let overlayCenterY
        else {
            return false
        }

        let edgeThreshold: CGFloat = 88
        let maxStepPerTick: CGFloat = 14
        var deltaY: CGFloat = 0
        let overlayCenterYInBounds = overlayCenterY - scrollView.contentOffset.y

        if overlayCenterYInBounds < (viewport.minY + edgeThreshold) {
            let ratio = ((viewport.minY + edgeThreshold) - overlayCenterYInBounds) / edgeThreshold
            deltaY = -maxStepPerTick * min(max(ratio, 0), 1)
        } else if overlayCenterYInBounds > (viewport.maxY - edgeThreshold) {
            let ratio = (overlayCenterYInBounds - (viewport.maxY - edgeThreshold)) / edgeThreshold
            deltaY = maxStepPerTick * min(max(ratio, 0), 1)
        }

        guard abs(deltaY) > 0.01 else { return false }

        let minOffsetY = -scrollView.adjustedContentInset.top
        let maxOffsetY = max(
            minOffsetY,
            scrollView.contentSize.height - scrollView.bounds.height + scrollView.adjustedContentInset.bottom
        )
        let currentOffsetY = scrollView.contentOffset.y
        let nextOffsetY = min(max(currentOffsetY + deltaY, minOffsetY), maxOffsetY)
        guard abs(nextOffsetY - currentOffsetY) > 0.01 else { return false }

        scrollView.setContentOffset(
            CGPoint(x: scrollView.contentOffset.x, y: nextOffsetY),
            animated: false
        )

        let now = CACurrentMediaTime()
        if now - lastAutoScrollLogTimestamp > 0.25 {
            cityListDebugLog(
                "autoscroll offset=\(nextOffsetY) " +
                "content=\(scrollView.contentSize.height) bounds=\(scrollView.bounds.height)"
            )
            lastAutoScrollLogTimestamp = now
        }

        return true
    }

    func rowOffset(for rowIndex: Int, rowStride: CGFloat) -> CGFloat {
        guard
            let sourceIndex,
            let proposedIndex,
            draggedCityID != nil
        else {
            return 0
        }

        if rowIndex == sourceIndex {
            return 0
        }

        if proposedIndex > sourceIndex, (sourceIndex + 1...proposedIndex).contains(rowIndex) {
            return -rowStride
        }

        if proposedIndex < sourceIndex, (proposedIndex..<sourceIndex).contains(rowIndex) {
            return rowStride
        }

        return 0
    }

    func commitReorder(cities: inout [City]) -> Bool {
        guard
            let sourceIndex,
            let proposedIndex,
            cities.indices.contains(sourceIndex)
        else {
            DispatchQueue.main.async { [weak self] in self?.reset() }
            return false
        }

        let destination = max(0, min(cities.count - 1, proposedIndex))
        guard sourceIndex != destination else {
            DispatchQueue.main.async { [weak self] in self?.reset() }
            return false
        }

        let movedCity = cities.remove(at: sourceIndex)
        cities.insert(movedCity, at: destination)
        cityListDebugLog("REORDER drag end source=\(sourceIndex) destination=\(destination)")
        DispatchQueue.main.async { [weak self] in self?.reset() }
        return true
    }

    func cancel(reason: String) {
        guard isReordering else { return }
        cityListDebugLog("REORDER cancel reason=\(reason)")
        reset()
    }

    private var overlayCenterY: CGFloat? {
        guard let dragInitialFrame else { return nil }
        return dragInitialFrame.midY + dragTranslationY
    }

    private func calculatedDestinationIndex(
        cityOrder: [City],
        rowFrames: [City.ID: CGRect],
        overlayCenterY: CGFloat
    ) -> Int {
        guard let draggedCityID, !cityOrder.isEmpty else { return 0 }

        let orderedOtherRows = cityOrder
            .enumerated()
            .filter { $0.element.id != draggedCityID }
            .sorted { lhs, rhs in
                let leftMinY = rowFrames[lhs.element.id]?.minY ?? .greatestFiniteMagnitude
                let rightMinY = rowFrames[rhs.element.id]?.minY ?? .greatestFiniteMagnitude
                return leftMinY < rightMinY
            }

        var insertionIndex = 0
        for (_, city) in orderedOtherRows {
            guard let frame = rowFrames[city.id] else { continue }
            if overlayCenterY > frame.midY {
                insertionIndex += 1
            }
        }

        return max(0, min(cityOrder.count - 1, insertionIndex))
    }

    private func reset() {
        if isReordering {
            cityListDebugLog("isReordering -> false")
        }
        isReordering = false
        setScrollDisabled(false)
        draggedCityID = nil
        sourceIndex = nil
        proposedIndex = nil
        dragInitialFrame = nil
        dragTranslationY = 0
    }

    private func startObservingScrollView(_ scrollView: UIScrollView) {
        guard ENABLE_SCROLL_PROBE else { return }

        scrollBoundsObservation = scrollView.observe(\.bounds, options: [.new]) { _, change in
            guard let bounds = change.newValue else { return }
            print("[SCROLLPROBE] boundsHeight=\(Int(bounds.height.rounded()))")
        }

        scrollContentSizeObservation = scrollView.observe(\.contentSize, options: [.new]) { _, change in
            guard let contentSize = change.newValue else { return }
            print("[SCROLLPROBE] contentHeight=\(Int(contentSize.height.rounded()))")
        }

        scrollContentOffsetObservation = scrollView.observe(\.contentOffset, options: [.new]) { [weak self] _, change in
            guard let self, let offset = change.newValue else { return }
            let now = CACurrentMediaTime()
            Task { @MainActor in
                guard now - self.lastScrollProbeOffsetLogTimestamp > 0.20 else { return }
                self.lastScrollProbeOffsetLogTimestamp = now
                print("[SCROLLPROBE] contentOffsetY=\(Int(offset.y.rounded()))")
            }
        }
    }

    private func stopObservingScrollView() {
        scrollBoundsObservation = nil
        scrollContentSizeObservation = nil
        scrollContentOffsetObservation = nil
    }

    private func applyScrollEnabledState() {
        guard let scrollView else { return }
        let shouldEnableScroll = !isScrollDisabled
        if scrollView.isScrollEnabled != shouldEnableScroll {
            scrollView.isScrollEnabled = shouldEnableScroll
            if ENABLE_SCROLL_PROBE {
                print("[SCROLLPROBE] native isScrollEnabled=\(scrollView.isScrollEnabled)")
            }
        }
    }
}

private struct CityRowFramePreferenceKey: PreferenceKey {
    static let defaultValue: [City.ID: CGRect] = [:]

    static func reduce(value: inout [City.ID: CGRect], nextValue: () -> [City.ID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

private struct ScrollViewIntrospector: UIViewRepresentable {
    let onResolve: (UIScrollView) -> Void

    func makeUIView(context: Context) -> ScrollIntrospectionView {
        ScrollIntrospectionView(onResolve: onResolve)
    }

    func updateUIView(_ uiView: ScrollIntrospectionView, context: Context) {
        uiView.onResolve = onResolve
        uiView.resolveIfNeeded()
    }
}

private final class ScrollIntrospectionView: UIView {
    var onResolve: (UIScrollView) -> Void
    private var didResolveScrollView = false
    private var didRetryResolution = false

    init(onResolve: @escaping (UIScrollView) -> Void) {
        self.onResolve = onResolve
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        backgroundColor = .clear
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        resolveIfNeeded()
    }

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        resolveIfNeeded()
    }

    func resolveIfNeeded() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard !self.didResolveScrollView else { return }

            if let scrollView = self.resolveScrollView() {
                self.didResolveScrollView = true
                self.onResolve(scrollView)
                return
            }

            guard !self.didRetryResolution else { return }
            self.didRetryResolution = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                self?.resolveIfNeeded()
            }
        }
    }

    private func resolveScrollView() -> UIScrollView? {
        if let ancestorScrollView = firstAncestorScrollView(startingFrom: self) {
            return ancestorScrollView
        }

        guard let window else { return nil }

        let probePoint = convert(CGPoint(x: bounds.midX, y: bounds.midY), to: window)
        if let hitView = window.hitTest(probePoint, with: nil),
           let hitScrollView = firstAncestorScrollView(startingFrom: hitView) {
            return hitScrollView
        }

        if let containingScrollView = firstDescendantScrollView(in: window, containing: probePoint) {
            return containingScrollView
        }

        return nil
    }

    private func firstAncestorScrollView(startingFrom view: UIView?) -> UIScrollView? {
        var current: UIView? = view
        while let node = current {
            if let scrollView = node as? UIScrollView {
                return scrollView
            }
            current = node.superview
        }
        return nil
    }

    private func firstDescendantScrollView(in root: UIView, containing windowPoint: CGPoint) -> UIScrollView? {
        if let scrollView = root as? UIScrollView {
            let rectInWindow = scrollView.convert(scrollView.bounds, to: nil)
            if rectInWindow.contains(windowPoint) {
                return scrollView
            }
        }

        for child in root.subviews {
            if let found = firstDescendantScrollView(in: child, containing: windowPoint) {
                return found
            }
        }

        return nil
    }
}

private final class ScrollViewHolder: ObservableObject {
    @Published private(set) var scrollView: UIScrollView? = nil

    @discardableResult
    func setIfChanged(_ sv: UIScrollView?) -> Bool {
        guard let sv else { return false }
        guard scrollView !== sv else { return false }
        scrollView = sv
        return true
    }
}

private struct RowLongPressDriverModifier: ViewModifier {
    let enabled: Bool
    let scrollView: UIScrollView?
    let onBegan: (_ touchYContent: CGFloat, _ contentOffsetY: CGFloat) -> Void
    let onChanged: (CGFloat) -> Void
    let onEnded: () -> Void
    let onCancelled: () -> Void

    func body(content: Content) -> some View {
        content.overlay {
            RowLongPressDriverView(
                enabled: enabled,
                scrollView: scrollView,
                minimumPressDuration: 0.30,
                allowableMovement: 12,
                onBegan: onBegan,
                onChanged: onChanged,
                onEnded: onEnded,
                onCancelled: onCancelled
            )
            .allowsHitTesting(enabled)
        }
    }
}

private struct RowLongPressDriverView: UIViewRepresentable {
    let enabled: Bool
    let scrollView: UIScrollView?
    let minimumPressDuration: TimeInterval
    let allowableMovement: CGFloat
    let onBegan: (_ touchYContent: CGFloat, _ contentOffsetY: CGFloat) -> Void
    let onChanged: (CGFloat) -> Void
    let onEnded: () -> Void
    let onCancelled: () -> Void

    func makeUIView(context: Context) -> RowLongPressDriverUIView {
        RowLongPressDriverUIView()
    }

    func updateUIView(_ uiView: RowLongPressDriverUIView, context: Context) {
        uiView.update(
            enabled: enabled,
            scrollView: scrollView,
            minimumPressDuration: minimumPressDuration,
            allowableMovement: allowableMovement,
            onBegan: onBegan,
            onChanged: onChanged,
            onEnded: onEnded,
            onCancelled: onCancelled
        )
    }
}

private final class RowLongPressDriverUIView: UIView, UIGestureRecognizerDelegate {
    private lazy var longPressRecognizer: UILongPressGestureRecognizer = {
        let recognizer = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        recognizer.delegate = self
        recognizer.cancelsTouchesInView = false
        recognizer.delaysTouchesBegan = false
        return recognizer
    }()

    private var initialTouchYContent: CGFloat?
    private weak var scrollView: UIScrollView?
    private var onBegan: ((_ touchYContent: CGFloat, _ contentOffsetY: CGFloat) -> Void)?
    private var onChanged: ((CGFloat) -> Void)?
    private var onEnded: (() -> Void)?
    private var onCancelled: (() -> Void)?
    private var hasInjectedScrollView = false
    private static var didLogMissingInjectedScrollView = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        addGestureRecognizer(longPressRecognizer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(
        enabled: Bool,
        scrollView: UIScrollView?,
        minimumPressDuration: TimeInterval,
        allowableMovement: CGFloat,
        onBegan: @escaping (_ touchYContent: CGFloat, _ contentOffsetY: CGFloat) -> Void,
        onChanged: @escaping (CGFloat) -> Void,
        onEnded: @escaping () -> Void,
        onCancelled: @escaping () -> Void
    ) {
        if let scrollView {
            self.scrollView = scrollView
            hasInjectedScrollView = true
            Self.didLogMissingInjectedScrollView = false
        } else if self.scrollView == nil {
            hasInjectedScrollView = false
        }
        self.onBegan = onBegan
        self.onChanged = onChanged
        self.onEnded = onEnded
        self.onCancelled = onCancelled
        longPressRecognizer.minimumPressDuration = minimumPressDuration
        longPressRecognizer.allowableMovement = allowableMovement
        longPressRecognizer.isEnabled = enabled
    }

    @objc
    private func handleLongPress(_ recognizer: UILongPressGestureRecognizer) {
        switch recognizer.state {
        case .began:
            guard let metrics = currentGestureMetrics(for: recognizer) else { return }
            initialTouchYContent = metrics.touchPointContent.y
            onBegan?(metrics.touchPointContent.y, metrics.contentOffsetY)
            onChanged?(0)
        case .changed:
            guard let initialTouchYContent else { return }
            guard let metrics = currentGestureMetrics(for: recognizer) else {
                self.initialTouchYContent = nil
                onCancelled?()
                return
            }
            onChanged?(metrics.touchPointContent.y - initialTouchYContent)
        case .ended:
            initialTouchYContent = nil
            onEnded?()
        case .cancelled, .failed:
            initialTouchYContent = nil
            onCancelled?()
        default:
            break
        }
    }

    private func currentGestureMetrics(for recognizer: UILongPressGestureRecognizer) -> (
        touchPointContent: CGPoint,
        contentOffsetY: CGFloat
    )? {
        guard let scrollView else {
            #if DEBUG
            if ENABLE_SCROLL_PROBE, !Self.didLogMissingInjectedScrollView {
                print("[REORDER] abort begin: injected UIScrollView missing (holder=\(hasInjectedScrollView))")
                Self.didLogMissingInjectedScrollView = true
            }
            #endif
            return nil
        }
        Self.didLogMissingInjectedScrollView = false

        let touchPointContent = pointInContentSpace(recognizer: recognizer, scrollView: scrollView)
        return (
            touchPointContent: touchPointContent,
            contentOffsetY: scrollView.contentOffset.y
        )
    }

    private func pointInContentSpace(
        recognizer: UILongPressGestureRecognizer,
        scrollView: UIScrollView
    ) -> CGPoint {
        let boundsPoint = recognizer.location(in: scrollView)
        let contentOffset = scrollView.contentOffset
        return CGPoint(
            x: boundsPoint.x + contentOffset.x,
            y: boundsPoint.y + contentOffset.y
        )
    }

    private func isScrollPanRecognizer(_ recognizer: UIGestureRecognizer) -> Bool {
        guard recognizer is UIPanGestureRecognizer else { return false }
        var currentView: UIView? = recognizer.view
        while let view = currentView {
            if view is UIScrollView {
                return true
            }
            currentView = view.superview
        }
        return false
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        guard gestureRecognizer === longPressRecognizer else { return false }
        guard isScrollPanRecognizer(otherGestureRecognizer) else { return false }
        return longPressRecognizer.state == .possible
    }
}

// DEBUG-only pass-through probe that logs who wins hit-testing without consuming touches.
private struct HitTestProbeView: UIViewRepresentable {
    let tag: String
    let isReordering: Bool
    let overlayHitTesting: Bool

    func makeUIView(context: Context) -> HitTestProbeUIView {
        let view = HitTestProbeUIView()
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: HitTestProbeUIView, context: Context) {
        uiView.probeTag = tag
        uiView.isReordering = isReordering
        uiView.overlayHitTesting = overlayHitTesting
    }
}

private final class HitTestProbeUIView: UIView {
    var probeTag = "probe"
    var isReordering = false
    var overlayHitTesting = false
    private static var isResolvingHitTest = false
    private var lastTouchLogTimestamp: CFTimeInterval = 0

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        false
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard ENABLE_SCROLL_PROBE else { return nil }
        guard let touch = event?.allTouches?.first, touch.phase == .began else { return nil }

        let now = CACurrentMediaTime()
        guard now - lastTouchLogTimestamp > 0.15 else { return nil }
        lastTouchLogTimestamp = now

        guard let window else { return nil }
        let windowPoint = convert(point, to: window)

        var winnerDescription = "nil"
        if !Self.isResolvingHitTest {
            Self.isResolvingHitTest = true
            let winner = window.hitTest(windowPoint, with: event)
            if let winner {
                winnerDescription = String(describing: type(of: winner))
            }
            Self.isResolvingHitTest = false
        }

        print(
            "[HITPROBE] tag=\(probeTag) x=\(Int(windowPoint.x.rounded())) y=\(Int(windowPoint.y.rounded())) " +
            "winner=\(winnerDescription) isReordering=\(isReordering) overlayHitTesting=\(overlayHitTesting)"
        )
        return nil
    }
}

#if DEBUG
private let ENABLE_SCROLL_PROBE = true
private let ENABLE_CITYLIST_DEBUG = false
private let DISABLE_REORDER = false
#else
private let ENABLE_SCROLL_PROBE = false
private let ENABLE_CITYLIST_DEBUG = false
private let DISABLE_REORDER = false
#endif

private func cityListDebugLog(_ message: String) {
    #if DEBUG
    guard ENABLE_CITYLIST_DEBUG || ENABLE_SCROLL_PROBE else { return }
    print("[CITYLIST] \(message)")
    #endif
}
