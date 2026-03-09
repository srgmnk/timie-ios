import Foundation

struct EmptyStateQuote: Identifiable, Equatable {
    let id: String
    let text: String
    let attribution: String?
}

struct EmptyStateQuoteProvider {
    private let quotes: [EmptyStateQuote]

    init(quotes: [EmptyStateQuote] = Self.defaultQuotes) {
        self.quotes = quotes
    }

    var currentQuote: EmptyStateQuote {
        quotes.first ?? EmptyStateQuote(id: "fallback", text: "", attribution: nil)
    }

    func randomQuote() -> EmptyStateQuote? {
        quotes.randomElement()
    }

    private static let defaultQuotes: [EmptyStateQuote] = [
        EmptyStateQuote(
            id: "sartre-three-oclock",
            text: "Three o'clock is always too late or too early for anything you want to do",
            attribution: "Jean-Paul Sartre"
        )
    ]
}
