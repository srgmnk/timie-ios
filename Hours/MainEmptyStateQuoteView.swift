import SwiftUI

struct MainEmptyStateQuoteView: View {
    @Environment(\.appTheme) private var theme
    let quote: Quote

    private var trimmedAuthor: String? {
        let author = quote.author.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !author.isEmpty
        else {
            return nil
        }
        return author
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "quote.opening")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(theme.textSecondary)

            VStack(spacing: 16) {
                Text(quote.text)
                    .font(.system(size: 24, weight: .medium))
                    .tracking(-0.72)

                if let author = trimmedAuthor {
                    Text(author)
                        .font(.system(size: 14, weight: .medium))
                        .tracking(-0.42)
                }
            }
            .id(quote.id)
            .transition(.opacity)
        }
        .multilineTextAlignment(.center)
        .foregroundStyle(theme.textSecondary)
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .animation(.easeInOut(duration: 0.25), value: quote.id)
    }
}
