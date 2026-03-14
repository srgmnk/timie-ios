import SwiftUI
import UIKit
import MessageUI

private enum RowTrailing {
    case text(String)
    case symbol(String)
}

struct SettingsSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.appTheme) private var theme
    @AppStorage(CityViewPreference.storageKey) private var cityViewPreferenceRawValue = CityViewPreference.basic.rawValue
    @AppStorage(AppTimeFormatPreference.storageKey) private var timeFormatPreferenceRawValue = AppTimeFormatPreference.system.rawValue
    @AppStorage(AppAppearancePreference.storageKey) private var appearancePreferenceRawValue = AppAppearancePreference.system.rawValue
    @State private var isMailComposerPresented = false
    @State private var presentedLegalDocument: LegalDocument?

    private let linkRows = [
        (title: "Rate on the App Store", trailing: RowTrailing.text("ver 1.0.1")),
        (title: "Contact Me", trailing: RowTrailing.text("Any suggestions?")),
        (title: "Privacy Policy", trailing: RowTrailing.symbol("arrow.up.forward")),
        (title: "Terms of Use", trailing: RowTrailing.symbol("arrow.up.forward"))
    ]

    private var selectedCityViewPreference: CityViewPreference {
        CityViewPreference.from(rawValue: cityViewPreferenceRawValue)
    }

    private var selectedTimeFormatPreference: AppTimeFormatPreference {
        get { AppTimeFormatPreference.from(rawValue: timeFormatPreferenceRawValue) }
        set { timeFormatPreferenceRawValue = newValue.rawValue }
    }

    private var selectedAppearancePreference: AppAppearancePreference {
        AppAppearancePreference.from(rawValue: appearancePreferenceRawValue)
    }

    private var resolvedParallaxVariant: SettingsParallaxIllustrationView.Variant {
        let systemVariant: SettingsParallaxIllustrationView.Variant = theme.variant == .dark ? .dark : .light

        switch selectedAppearancePreference {
        case .light:
            return .light
        case .dark:
            return .dark
        case .system:
            return systemVariant
        }
    }

    private var mailRecipient: String { "hi@sergy.xyz" }
    private var mailSubject: String { "Hours — Contact" }
    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
    }
    private var appBuild: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown"
    }
    private var appearanceSettingDescription: String { selectedAppearancePreference.displayTitle }
    private var mailBody: String {
        let locale = Locale.current.identifier
        let timeZone = TimeZone.current.identifier
        let iOSVersion = UIDevice.current.systemVersion
        let deviceModel = UIDevice.current.model
        let deviceName = UIDevice.current.name
        let hardwareIdentifier = Self.hardwareIdentifier() ?? "Unknown"

        return """
        Hello,

        [Write your message here]

        ---
        App: Hours
        Version: \(appVersion) (\(appBuild))
        iOS: \(iOSVersion)
        Device: \(deviceModel) (\(deviceName))
        Device Identifier: \(hardwareIdentifier)
        Locale: \(locale)
        Time Zone: \(timeZone)
        Time Format Setting: \(selectedTimeFormatPreference.displayTitle)
        Appearance Setting: \(appearanceSettingDescription)
        """
    }

    var body: some View {
        NavigationStack {
            ZStack {
                SheetStyle.appScreenBackground(for: theme)
                    .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {

                        VStack(spacing: -8) {
                            Text("Catch")
                            Text("the moment")
                            Text("in hours")
                        }
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(Color(red: 78.0 / 255.0, green: 80.0 / 255.0, blue: 89.0 / 255.0))
                        .tracking(-0.96)
                        .multilineTextAlignment(.center)
                        .padding(.top, -16)

                        heroSection
                            .padding(.top, -32)

                        settingsBlock
                            .padding(.top, 12)
                            .padding(.horizontal, 8)

                        linksBlock
                            .padding(.top, 8)
                            .padding(.horizontal, 8)

                        footer
                            .padding(.top, 56)
                            .padding(.bottom, 32)
                            .padding(.horizontal, 40)
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.top, 32)
                    .frame(maxWidth: .infinity, alignment: .top)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    closeButton
                }
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .sheet(isPresented: $isMailComposerPresented) {
            MailComposeView(
                recipients: [mailRecipient],
                subject: mailSubject,
                messageBody: mailBody
            )
        }
        .sheet(item: $presentedLegalDocument) { document in
            LegalDocumentSheet(document: document)
        }
    }
    

    private var heroSection: some View {
        SettingsParallaxIllustrationView(variant: resolvedParallaxVariant)
            .id("settings-parallax-\(resolvedParallaxVariant.rawValue)")
            .frame(maxWidth: .infinity)
            .accessibilityHidden(true)
            .frame(maxWidth: .infinity, alignment: .top)
    }

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 15, weight: .medium))
        }
        .buttonStyle(.plain)
    }

    private var settingsBlock: some View {
        VStack(spacing: 1) {
            cityViewRow
                .background(groupedRowBackground(for: 0, total: 3))

            timeFormatRow
                .background(groupedRowBackground(for: 1, total: 3))

            appearanceRow
                .background(groupedRowBackground(for: 2, total: 3))
        }
    }

    private var cityViewRow: some View {
        HStack(spacing: 16) {
            Text("City View")
                .font(.system(size: 16, weight: .regular))
                .tracking(-0.48)
                .foregroundStyle(theme.textPrimary)

            Spacer(minLength: 0)

            Menu {
                ForEach(CityViewPreference.allCases, id: \.self) { preference in
                    Button {
                        cityViewPreferenceRawValue = preference.rawValue
                        triggerNotificationHaptic(.success)
                    } label: {
                        if preference == selectedCityViewPreference {
                            Label(preference.displayTitle, systemImage: "checkmark")
                        } else {
                            Text(preference.displayTitle)
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(selectedCityViewPreference.displayTitle)
                        .font(.system(size: 16, weight: .medium))
                        .tracking(-0.48)
                        .foregroundStyle(theme.textPrimary)

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(theme.tagNeutralText)
                }
                .padding(.leading, 16)
                .padding(.trailing, 12)
                .frame(height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(theme.surfaceControl)
                )
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .simultaneousGesture(
                TapGesture().onEnded {
                    triggerImpactHaptic(.medium)
                }
            )
        }
        .padding(.leading, 20)
        .padding(.trailing, 8)
        .frame(height: 64)
    }

    private var timeFormatRow: some View {
        HStack(spacing: 16) {
            Text("Time Format")
                .font(.system(size: 16, weight: .regular))
                .tracking(-0.48)
                .foregroundStyle(theme.textPrimary)

            Spacer(minLength: 0)

            Menu {
                ForEach(AppTimeFormatPreference.allCases, id: \.self) { preference in
                    Button {
                        timeFormatPreferenceRawValue = preference.rawValue
                        triggerNotificationHaptic(.success)
                    } label: {
                        if preference == selectedTimeFormatPreference {
                            Label(preference.displayTitle, systemImage: "checkmark")
                        } else {
                            Text(preference.displayTitle)
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(selectedTimeFormatPreference.displayTitle)
                        .font(.system(size: 16, weight: .medium))
                        .tracking(-0.48)
                        .foregroundStyle(theme.textPrimary)

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(theme.tagNeutralText)
                }
                .padding(.leading, 16)
                .padding(.trailing, 12)
                .frame(height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(theme.surfaceControl)
                )
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .simultaneousGesture(
                TapGesture().onEnded {
                    triggerImpactHaptic(.medium)
                }
            )
        }
        .padding(.leading, 20)
        .padding(.trailing, 8)
        .frame(height: 64)
    }

    private var appearanceRow: some View {
        HStack(spacing: 16) {
            Text("Appearance")
                .font(.system(size: 16, weight: .regular))
                .tracking(-0.48)
                .foregroundStyle(theme.textPrimary)

            Spacer(minLength: 0)

            Menu {
                ForEach(AppAppearancePreference.allCases, id: \.self) { preference in
                    Button {
                        appearancePreferenceRawValue = preference.rawValue
                        triggerNotificationHaptic(.success)
                    } label: {
                        if preference == selectedAppearancePreference {
                            Label(preference.displayTitle, systemImage: "checkmark")
                        } else {
                            Text(preference.displayTitle)
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(selectedAppearancePreference.displayTitle)
                        .font(.system(size: 16, weight: .medium))
                        .tracking(-0.48)
                        .foregroundStyle(theme.textPrimary)

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(theme.tagNeutralText)
                }
                .padding(.leading, 16)
                .padding(.trailing, 12)
                .frame(height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(theme.surfaceControl)
                )
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .simultaneousGesture(
                TapGesture().onEnded {
                    triggerImpactHaptic(.medium)
                }
            )
        }
        .padding(.leading, 20)
        .padding(.trailing, 8)
        .frame(height: 64)
    }

    private var linksBlock: some View {
        VStack(spacing: 1) {
            ForEach(Array(linkRows.enumerated()), id: \.offset) { index, row in
                let onTapHandler: (() -> Void)? = {
                    switch row.title {
                    case "Contact Me":
                        presentContactMe()
                    case "Privacy Policy":
                        presentedLegalDocument = .privacy
                    case "Terms of Use":
                        presentedLegalDocument = .terms
                    default:
                        return
                    }
                }

                SettingsLinkRow(
                    title: row.title,
                    trailing: row.trailing,
                    onTap: onTapHandler
                )
                    .background(groupedRowBackground(for: index, total: linkRows.count))
            }
        }
    }

    private func presentContactMe() {
        if MFMailComposeViewController.canSendMail() {
            isMailComposerPresented = true
            return
        }

        var components = URLComponents()
        components.scheme = "mailto"
        components.path = mailRecipient
        components.queryItems = [
            URLQueryItem(name: "subject", value: mailSubject),
            URLQueryItem(name: "body", value: mailBody)
        ]

        guard let url = components.url else { return }
        openURL(url)
    }

    private static func hardwareIdentifier() -> String? {
        var systemInfo = utsname()
        uname(&systemInfo)

        let identifier = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0)
            }
        }

        let trimmed = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func triggerImpactHaptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }

    private func triggerNotificationHaptic(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }

    private var footer: some View {
        VStack(spacing: 20) {
            Image(systemName: "heart.gauge.open")
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(theme.textSubdued)
            
            Text("built by one person simply because I’d wanted\nit for a long time")
                .font(.system(size: 14, weight: .regular))
                .tracking(-0.42)
                .multilineTextAlignment(.center)
                .foregroundStyle(theme.textSubdued)

            Text("fortis imaginatio generat casum\n© 2026")
                .font(.system(size: 14, weight: .regular))
                .tracking(-0.42)
                .multilineTextAlignment(.center)
                .foregroundStyle(theme.textSubdued)
        }
    }

    @ViewBuilder
    private func groupedRowBackground(for index: Int, total: Int) -> some View {
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
}

private struct SettingsLinkRow: View {
    @Environment(\.appTheme) private var theme
    let title: String
    let trailing: RowTrailing?
    let onTap: (() -> Void)?

    @ViewBuilder
    private var rowContent: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 16, weight: .regular))
                .tracking(-0.48)
                .foregroundStyle(theme.textPrimary)

            Spacer(minLength: 0)

            if let trailing {
                switch trailing {
                case .text(let value):
                    Text(value)
                        .font(.system(size: 16, weight: .regular))
                        .tracking(-0.48)
                        .foregroundStyle(theme.textSubdued)
                case .symbol(let name):
                    Image(systemName: name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(theme.textSubdued)
                }
            }
        }
        .padding(.horizontal, 20)
        .frame(height: 64)
    }

    var body: some View {
        if let onTap {
            Button(action: onTap) {
                rowContent
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
        } else {
            rowContent
        }
    }
}

private struct MailComposeView: UIViewControllerRepresentable {
    let recipients: [String]
    let subject: String
    let messageBody: String

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let controller = MFMailComposeViewController()
        controller.mailComposeDelegate = context.coordinator
        controller.setToRecipients(recipients)
        controller.setSubject(subject)
        controller.setMessageBody(messageBody, isHTML: false)
        return controller
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {
        // No-op
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        func mailComposeController(
            _ controller: MFMailComposeViewController,
            didFinishWith result: MFMailComposeResult,
            error: Error?
        ) {
            controller.dismiss(animated: true)
        }
    }
}
