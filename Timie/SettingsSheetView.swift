import SwiftUI
import UIKit

struct SettingsSheetView: View {
    @Environment(\.dismiss) private var dismiss

    private let settingsRows = [
        (title: "Time format", value: "System"),
        (title: "Appearance", value: "System")
    ]

    private let linkRows = [
        (title: "Rate on the App Store", trailing: "ver 1.0.1"),
        (title: "Privacy Policy", trailing: nil as String?),
        (title: "Terms & Conditions", trailing: nil as String?),
        (title: "Contact Me", trailing: nil as String?)
    ]

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    heroSection
                    
                    VStack(spacing: -6) {
                        Text("Catch the moment")
                        Text("in hours")
                    }
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(Color(red: 78.0 / 255.0, green: 80.0 / 255.0, blue: 89.0 / 255.0))
                    .tracking(-0.96)
                    .multilineTextAlignment(.center)
                    .padding(.top, -16)
                    .padding(.bottom, 56)
                    
                    settingsBlock
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
                .padding(.top, -88)
                .frame(maxWidth: .infinity, alignment: .top)
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
    }
    

    private var heroSection: some View {
        Image("SettingsTopIllustration")
            .resizable()
            .scaledToFit()
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
        VStack(spacing: 2) {
            ForEach(Array(settingsRows.enumerated()), id: \.offset) { index, row in
                SettingsValueRow(title: row.title, value: row.value)
                    .background(groupedRowBackground(for: index, total: settingsRows.count))
            }
        }
    }

    private var linksBlock: some View {
        VStack(spacing: 2) {
            ForEach(Array(linkRows.enumerated()), id: \.offset) { index, row in
                SettingsLinkRow(title: row.title, trailingText: row.trailing)
                    .background(groupedRowBackground(for: index, total: linkRows.count))
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 20) {
            Image(systemName: "heart.gauge.open")
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(Color.black.opacity(0.15))
            
            Text("built by one person simply because I’d wanted\nit for a long time")
                .font(.system(size: 14, weight: .regular))
                .tracking(-0.42)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.black.opacity(0.15))

            Text("fortis imaginatio generat casum\n© 2026")
                .font(.system(size: 14, weight: .regular))
                .tracking(-0.42)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.black.opacity(0.15))
        }
    }

    @ViewBuilder
    private func groupedRowBackground(for index: Int, total: Int) -> some View {
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
}

private struct SettingsValueRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 16) {
            Text(title)
                .font(.system(size: 16, weight: .regular))
                .tracking(-0.48)
                .foregroundStyle(.black)

            Spacer(minLength: 0)

            HStack(spacing: 4) {
                Text(value)
                    .font(.system(size: 16, weight: .medium))
                    .tracking(-0.48)
                    .foregroundStyle(.black)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.3))
            }
            .padding(.leading, 16)
            .padding(.trailing, 12)
            .frame(height: 48)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.black.opacity(0.05))
            )
        }
        .padding(.leading, 20)
        .padding(.trailing, 8)
        .frame(height: 64)
    }
}

private struct SettingsLinkRow: View {
    let title: String
    let trailingText: String?

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 16, weight: .regular))
                .tracking(-0.48)
                .foregroundStyle(.black)

            Spacer(minLength: 0)

            if let trailingText {
                Text(trailingText)
                    .font(.system(size: 16, weight: .regular))
                    .tracking(-0.48)
                    .foregroundStyle(Color.black.opacity(0.15))
            }
        }
        .padding(.horizontal, 20)
        .frame(height: 64)
    }
}
