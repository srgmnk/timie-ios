import SwiftUI
import UIKit

struct AddCitySheetView: View {
    let existingCanonicalIDs: Set<String>
    let onSelect: (CitySearchItem) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.displayScale) private var displayScale
    @Environment(\.appTheme) private var theme
    @State private var query = ""
    @State private var results: [CitySearchItem] = []
    @State private var searchTask: Task<Void, Never>?
    @State private var isSearchFieldFocused = false
    @StateObject private var currentLocationProvider = CurrentLocationCityProvider()

    private struct DisplayResult: Identifiable {
        let item: CitySearchItem?
        let isCurrentLocation: Bool

        var id: String {
            if isCurrentLocation {
                return "current-location-row"
            }
            return "city-result-\(item?.canonicalIdentity ?? "unknown")"
        }
    }

    private struct DisplaySection: Identifiable {
        let id: String
        let results: [DisplayResult]
    }

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var emptyStateTitle: String {
        "No results for \"\(trimmedQuery)\""
    }

    private var isShowingEmptySearchState: Bool {
        !trimmedQuery.isEmpty && results.isEmpty
    }

    private var rowSeparatorHeight: CGFloat {
        3 / max(displayScale, 1)
    }

    private var displayedSections: [DisplaySection] {
        let mappedResults = results.map { DisplayResult(item: $0, isCurrentLocation: false) }

        guard trimmedQuery.isEmpty else {
            return [DisplaySection(id: "search-results", results: mappedResults)]
        }

        var primaryResults: [DisplayResult] = []
        if currentLocationProvider.permissionState == .authorized {
            primaryResults.append(
                DisplayResult(item: currentLocationProvider.currentCityItem, isCurrentLocation: true)
            )
        }
        let referenceItems = CitySearchProvider.shared.referenceItemsForZeroState()
        primaryResults.append(contentsOf: referenceItems.map { DisplayResult(item: $0, isCurrentLocation: false) })

        let secondaryResults = CitySearchProvider.shared
            .popularCitiesForZeroState()
            .map { DisplayResult(item: $0, isCurrentLocation: false) }

        var sections: [DisplaySection] = []
        if !primaryResults.isEmpty {
            sections.append(DisplaySection(id: "zero-state-primary", results: primaryResults))
        }
        if !secondaryResults.isEmpty {
            sections.append(DisplaySection(id: "zero-state-secondary", results: secondaryResults))
        }

        return sections
    }

    var body: some View {
        let referenceDate = Date()
        let visibleSections = displayedSections

        NavigationStack {
            List {
                ForEach(Array(visibleSections.enumerated()), id: \.element.id) { sectionIndex, section in
                    ForEach(Array(section.results.enumerated()), id: \.element.id) { rowIndex, displayResult in
                        let item = displayResult.item
                        let isCurrentLocationRow = displayResult.isCurrentLocation
                        let isLocationLoadingRow = isCurrentLocationRow && item == nil
                        let isAlreadyAdded = item.map { existingCanonicalIDs.contains($0.canonicalIdentity) } ?? false

                        Button {
                            searchTask?.cancel()

                            guard let item else { return }
                            emptyBugLog(
                                "row tapped id=\(item.canonicalIdentity) city=\(item.city) " +
                                "alreadyAdded=\(isAlreadyAdded) query=\"\(trimmedQuery)\" main=\(Thread.isMainThread)"
                            )

                            guard !isAlreadyAdded else {
                                emptyBugLog("row already added; dismissing without callback id=\(item.canonicalIdentity)")
                                dismiss()
                                return
                            }

                            let generator = UINotificationFeedbackGenerator()
                            generator.notificationOccurred(.success)
                            emptyBugLog("invoking onSelect for id=\(item.canonicalIdentity)")
                            onSelect(item)
                            emptyBugLog("sending dismiss() for selected id=\(item.canonicalIdentity)")
                            dismiss()
                        } label: {
                            HStack(alignment: .center, spacing: 12) {
                                Text(rowPrimaryText(for: item, isCurrentLocationLoadingRow: isLocationLoadingRow))
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(theme.textPrimary)
                                    .lineLimit(1)
                                    .opacity(isLocationLoadingRow ? 0.2 : 1)
                                    .modifier(LocationPlaceholderShimmer(isActive: isLocationLoadingRow))

                                Spacer(minLength: 8)

                                CitySearchRowLabel(
                                    kind: rowLabelKind(
                                        for: item,
                                        isCurrentLocationRow: isCurrentLocationRow,
                                        isAlreadyAdded: isAlreadyAdded,
                                        referenceDate: referenceDate
                                    )
                                )
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 22)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(rowBackground(for: rowIndex, total: section.results.count))
                            .padding(.bottom, rowIndex == section.results.count - 1 ? 0 : rowSeparatorHeight)
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }

                    if sectionIndex < visibleSections.count - 1 {
                        let nextSection = visibleSections[sectionIndex + 1]
                        if section.id == "zero-state-primary" && nextSection.id == "zero-state-secondary" {
                            popularCitiesLabelRow
                                .listRowInsets(EdgeInsets())
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                        } else {
                            Color.clear
                                .frame(height: 8)
                                .environment(\.defaultMinListRowHeight, 8)
                                .listRowInsets(EdgeInsets())
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                        }
                    }
                }
            }
            .environment(\.defaultMinListRowHeight, 0)
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(SheetStyle.appScreenBackground(for: theme))
            .padding(.horizontal, 8)
            .navigationTitle("Add City")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .buttonStyle(.plain)
                }
            }
            .overlay {
                if isShowingEmptySearchState {
                    AddCityEmptyStateView(title: emptyStateTitle)
                }
            }
            .safeAreaInset(edge: .bottom) {
                bottomSearchArea
            }
        }
        .background(SheetStyle.appScreenBackground(for: theme).ignoresSafeArea())
        .onAppear {
            emptyBugLog("sheet onAppear existingIDsCount=\(existingCanonicalIDs.count)")
            performSearch(for: query)
            currentLocationProvider.requestCurrentCity()
            DispatchQueue.main.async {
                isSearchFieldFocused = true
            }
        }
        .onChange(of: query) { _, newQuery in
            performSearch(for: newQuery)
            if newQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                currentLocationProvider.requestCurrentCity()
            }
        }
        .onDisappear {
            emptyBugLog("sheet onDisappear")
            searchTask?.cancel()
            isSearchFieldFocused = false
        }
    }

    private var bottomSearchArea: some View {
        GlassEffectContainer(spacing: 10) {
            NativeBottomSearchTextField(
                text: $query,
                isFocused: $isSearchFieldFocused,
                placeholder: "Search"
            )
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .glassEffect(.regular, in: Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 16)
    }

    private var popularCitiesLabelRow: some View {
        HStack {
            Text("Popular cities")
                .font(.system(size: 14))
                .tracking(-0.42)
                .foregroundStyle(theme.textSecondary)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func performSearch(for query: String) {
        searchTask?.cancel()

        let local = CitySearchProvider.shared.localResults(
            matching: query,
            excluding: []
        )
        results = local

        guard CitySearchProvider.shared.shouldFetchFallback(for: query, localResultCount: local.count) else {
            return
        }

        searchTask = Task {
            let merged = await CitySearchProvider.shared.fallbackMergedResults(
                matching: query,
                localResults: local,
                excluding: []
            )

            guard !Task.isCancelled else { return }
            guard self.query == query else { return }

            await MainActor.run {
                results = merged
            }
        }
    }

    @ViewBuilder
    private func rowBackground(for index: Int, total: Int) -> some View {
        if total <= 1 {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(SheetStyle.groupedRowBackground(for: theme))
        } else if index == 0 {
            UnevenRoundedRectangle(
                cornerRadii: .init(topLeading: 24, bottomLeading: 0, bottomTrailing: 0, topTrailing: 24),
                style: .continuous
            )
            .fill(SheetStyle.groupedRowBackground(for: theme))
        } else if index == total - 1 {
            UnevenRoundedRectangle(
                cornerRadii: .init(topLeading: 0, bottomLeading: 24, bottomTrailing: 24, topTrailing: 0),
                style: .continuous
            )
            .fill(SheetStyle.groupedRowBackground(for: theme))
        } else {
            Rectangle()
                .fill(SheetStyle.groupedRowBackground(for: theme))
        }
    }

    private func utcOffsetText(for timeZoneIdentifier: String, referenceDate: Date) -> String {
        guard let timeZone = TimeZone(identifier: timeZoneIdentifier) else {
            return "UTC"
        }

        let seconds = timeZone.secondsFromGMT(for: referenceDate)
        let sign = seconds >= 0 ? "+" : "−"
        let absoluteSeconds = abs(seconds)
        let hours = absoluteSeconds / 3600
        let minutes = (absoluteSeconds % 3600) / 60

        if minutes == 0 {
            return "UTC\(sign)\(hours)"
        }

        return "UTC\(sign)\(hours):" + String(format: "%02d", minutes)
    }

    private func rowPrimaryText(for item: CitySearchItem?, isCurrentLocationLoadingRow: Bool) -> String {
        if isCurrentLocationLoadingRow {
            return "My location is ..."
        }

        guard let item else { return "" }
        if let specialReferenceKind = item.specialReferenceKind {
            return specialReferenceKind.descriptiveName
        }
        if item.country.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return item.city
        }
        return "\(item.city), \(item.country)"
    }

    private func rowLabelKind(
        for item: CitySearchItem?,
        isCurrentLocationRow: Bool,
        isAlreadyAdded: Bool,
        referenceDate: Date
    ) -> CitySearchRowLabel.Kind {
        if isCurrentLocationRow {
            if item == nil {
                return .locationLoading
            }
            return .myLocation
        }
        guard let item else {
            return .utc("UTC")
        }
        if isAlreadyAdded {
            return .added
        }
        if item.specialReferenceKind != nil {
            return .utc(item.city)
        }
        return .utc(utcOffsetText(for: item.timeZoneIdentifier, referenceDate: referenceDate))
    }

    private func emptyBugLog(_ message: String) {
        #if DEBUG
        print("[EMPTYBUG][AddCitySheet] \(message)")
        #endif
    }
}

private struct LocationPlaceholderShimmer: ViewModifier {
    let isActive: Bool

    func body(content: Content) -> some View {
        content
            .overlay {
                if isActive {
                    GeometryReader { proxy in
                        let width = max(proxy.size.width, 1)
                        TimelineView(.animation) { timeline in
                            let duration = 1.4
                            let progress = timeline.date.timeIntervalSinceReferenceDate
                                .truncatingRemainder(dividingBy: duration) / duration
                            let offset = CGFloat(progress) * width * 2.2 - width * 1.1

                            LinearGradient(
                                colors: [
                                    .clear,
                                    Color.white.opacity(0.35),
                                    .clear
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .frame(width: width * 0.85, height: proxy.size.height)
                            .offset(x: offset)
                        }
                    }
                    .mask(content)
                    .allowsHitTesting(false)
                }
            }
    }
}

private struct AddCityEmptyStateView: View {
    @Environment(\.appTheme) private var theme
    let title: String

    private var subtitle: String {
        "Check the spelling or try new search"
    }

    var body: some View {
        VStack(spacing: 0) {

            Image("AddCityEmptyStateIllustration")
                .resizable()
                .scaledToFit()
                .frame(width: 340, height: 262)
                .padding(.bottom, -80)

            VStack(spacing: 10) {

                Text(title)
                    .font(.system(size: 32, weight: .semibold))
                    .tracking(-0.96)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                Text(subtitle)
                    .font(.system(size: 14, weight: .medium))
                    .tracking(-0.42)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(theme.textSecondary)

            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 48)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .allowsHitTesting(false)
    }
}

private struct CitySearchRowLabel: View {
    @Environment(\.appTheme) private var theme
    enum Kind {
        case none
        case locationLoading
        case myLocation
        case added
        case referenceDescription(String)
        case utc(String)
    }

    let kind: Kind

    private var text: String {
        switch kind {
        case .none:
            return ""
        case .locationLoading:
            return ""
        case .myLocation:
            return "My location"
        case .added:
            return "Added"
        case .referenceDescription(let text):
            return text
        case .utc(let offset):
            return offset
        }
    }

    private var textColor: Color {
        switch kind {
        case .none:
            return .clear
        case .locationLoading:
            return theme.tagNeutralText
        case .added:
            return theme.tagAddedText
        case .myLocation, .referenceDescription, .utc:
            return theme.tagNeutralText
        }
    }

    private var backgroundColor: Color {
        switch kind {
        case .none:
            return theme.tagNeutralBackground
        case .locationLoading:
            return theme.tagNeutralBackground
        case .added:
            return theme.tagAddedBackground
        case .myLocation, .referenceDescription, .utc:
            return theme.tagNeutralBackground
        }
    }

    private var borderColor: Color {
        switch kind {
        case .none:
            return .clear
        case .locationLoading:
            return theme.separatorSoft
        case .added:
            return .clear
        case .myLocation, .referenceDescription, .utc:
            return theme.separatorSoft
        }
    }

    @ViewBuilder
    var body: some View {
        if case .none = kind {
            EmptyView()
        } else if case .locationLoading = kind {
            Image(systemName: "rays")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(textColor)
                .lineLimit(1)
                .padding(.horizontal, 8)
                .frame(height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(backgroundColor)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(borderColor, lineWidth: 1)
                )
        } else {
            Text(text)
                .font(.system(size: 14, weight: .regular))
                .tracking(-0.42)
                .foregroundStyle(textColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 8)
                .frame(height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(backgroundColor)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(borderColor, lineWidth: 1)
                )
        }
    }
}

private struct NativeBottomSearchTextField: UIViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool
    let placeholder: String

    func makeUIView(context: Context) -> UISearchTextField {
        let textField = UISearchTextField(frame: .zero)
        textField.delegate = context.coordinator
        textField.placeholder = placeholder
        textField.returnKeyType = .search
        textField.autocorrectionType = .no
        textField.autocapitalizationType = .words
        textField.clearButtonMode = .whileEditing
        textField.adjustsFontForContentSizeCategory = true
        textField.borderStyle = .none
        textField.backgroundColor = .clear
        textField.addTarget(context.coordinator, action: #selector(Coordinator.textDidChange(_:)), for: .editingChanged)
        return textField
    }

    func updateUIView(_ uiView: UISearchTextField, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        if uiView.placeholder != placeholder {
            uiView.placeholder = placeholder
        }

        if isFocused {
            guard !uiView.isFirstResponder else { return }
            DispatchQueue.main.async {
                uiView.becomeFirstResponder()
            }
        } else if uiView.isFirstResponder {
            uiView.resignFirstResponder()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, isFocused: $isFocused)
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        @Binding private var text: String
        @Binding private var isFocused: Bool

        init(text: Binding<String>, isFocused: Binding<Bool>) {
            _text = text
            _isFocused = isFocused
        }

        @objc func textDidChange(_ sender: UITextField) {
            text = sender.text ?? ""
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            isFocused = true
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            isFocused = false
        }

        func textFieldShouldClear(_ textField: UITextField) -> Bool {
            text = ""
            return true
        }
    }
}
