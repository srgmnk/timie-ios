import SwiftUI
import UIKit

struct AddCitySheetView: View {
    let existingTimeZoneIDs: Set<String>
    let onSelect: (CitySearchItem) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [CitySearchItem] = []
    @State private var searchTask: Task<Void, Never>?
    @State private var isSearchFieldFocused = false
    @StateObject private var currentLocationProvider = CurrentLocationCityProvider()

    private struct DisplayResult: Identifiable {
        let item: CitySearchItem
        let isCurrentLocation: Bool

        var id: String {
            "\(isCurrentLocation ? "current-location" : "city-result")-\(item.id)"
        }
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

    private var displayedResults: [DisplayResult] {
        let mappedResults = results.map { DisplayResult(item: $0, isCurrentLocation: false) }

        guard trimmedQuery.isEmpty, let locationItem = currentLocationProvider.currentCityItem else {
            return mappedResults
        }

        var displayed: [DisplayResult] = []
        displayed.append(DisplayResult(item: locationItem, isCurrentLocation: true))

        var seenTimeZones = Set<String>([locationItem.timeZoneIdentifier])
        var seenCityCountry = Set<String>([cityCountryKey(for: locationItem)])

        for mapped in mappedResults {
            if seenTimeZones.contains(mapped.item.timeZoneIdentifier) { continue }

            let cityCountry = cityCountryKey(for: mapped.item)
            if seenCityCountry.contains(cityCountry) { continue }

            displayed.append(mapped)
            seenTimeZones.insert(mapped.item.timeZoneIdentifier)
            seenCityCountry.insert(cityCountry)
        }

        return displayed
    }

    var body: some View {
        let referenceDate = Date()
        let visibleResults = displayedResults

        NavigationStack {
            List {
                ForEach(Array(visibleResults.enumerated()), id: \.element.id) { index, displayResult in
                    let item = displayResult.item
                    let isCurrentLocationRow = displayResult.isCurrentLocation
                    let isAlreadyAdded = existingTimeZoneIDs.contains(item.timeZoneIdentifier)

                    Button {
                        searchTask?.cancel()
                        guard !isAlreadyAdded else {
                            dismiss()
                            return
                        }

                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)
                        dismiss()
                        onSelect(item)
                    } label: {
                        HStack(alignment: .center, spacing: 12) {
                            Text("\(item.city), \(item.country)")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.primary)
                                .lineLimit(1)

                            Spacer(minLength: 8)

                            CitySearchRowLabel(
                                kind: isCurrentLocationRow
                                    ? .myLocation
                                    : (isAlreadyAdded
                                        ? .added
                                        : .utc(utcOffsetText(for: item.timeZoneIdentifier, referenceDate: referenceDate)))
                            )
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 22)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(rowBackground(for: index, total: visibleResults.count))
                        .padding(.bottom, index == visibleResults.count - 1 ? 0 : 2)
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
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
        .onAppear {
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
                .fill(SheetStyle.groupedRowBackground)
        } else if index == 0 {
            UnevenRoundedRectangle(
                cornerRadii: .init(topLeading: 24, bottomLeading: 0, bottomTrailing: 0, topTrailing: 24),
                style: .continuous
            )
            .fill(SheetStyle.groupedRowBackground)
        } else if index == total - 1 {
            UnevenRoundedRectangle(
                cornerRadii: .init(topLeading: 0, bottomLeading: 24, bottomTrailing: 24, topTrailing: 0),
                style: .continuous
            )
            .fill(SheetStyle.groupedRowBackground)
        } else {
            Rectangle()
                .fill(SheetStyle.groupedRowBackground)
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

    private func cityCountryKey(for item: CitySearchItem) -> String {
        "\(normalized(item.city))|\(normalized(item.country))"
    }

    private func normalized(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}

private struct AddCityEmptyStateView: View {
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
                .padding(.bottom, -40)

            VStack(spacing: 10) {

                Text(title)
                    .font(.system(size: 32, weight: .semibold))
                    .tracking(-0.96)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.black.opacity(0.2))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                Text(subtitle)
                    .font(.system(size: 14, weight: .medium))
                    .tracking(-0.42)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.black.opacity(0.2))

            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 48)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .allowsHitTesting(false)
    }
}

private struct CitySearchRowLabel: View {
    enum Kind {
        case myLocation
        case added
        case utc(String)
    }

    let kind: Kind

    private var text: String {
        switch kind {
        case .myLocation:
            return "My location"
        case .added:
            return "Added"
        case .utc(let offset):
            return offset
        }
    }

    private var textColor: Color {
        switch kind {
        case .added:
            return Color(red: 0x56 / 255, green: 0x82 / 255, blue: 0x22 / 255)
        case .myLocation, .utc:
            return Color.black.opacity(0.3)
        }
    }

    private var backgroundColor: Color {
        switch kind {
        case .added:
            return Color(red: 0xE8 / 255, green: 0xEC / 255, blue: 0xE3 / 255)
        case .myLocation, .utc:
            return .clear
        }
    }

    private var borderColor: Color {
        switch kind {
        case .added:
            return .clear
        case .myLocation, .utc:
            return Color.black.opacity(0.05)
        }
    }

    var body: some View {
        Text(text)
            .font(.system(size: 14, weight: .regular))
            .tracking(-0.42)
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
