import SwiftUI

struct MainEmptyStateQuoteView: View {
    let quote: EmptyStateQuote

    private var trimmedAttribution: String? {
        guard let attribution = quote.attribution?.trimmingCharacters(in: .whitespacesAndNewlines),
              !attribution.isEmpty
        else {
            return nil
        }
        return attribution
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "quote.opening")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.black.opacity(0.2))

            Text(quote.text)
                .font(.system(size: 24, weight: .medium))
                .tracking(-0.72)

            if let attribution = trimmedAttribution {
                Text(attribution)
                    .font(.system(size: 14, weight: .medium))
                    .tracking(-0.42)
            }
        }
        .multilineTextAlignment(.center)
        .foregroundStyle(.black.opacity(0.2))
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}
