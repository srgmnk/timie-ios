import Foundation
import Combine

struct Quote: Identifiable {
    let id = UUID()
    let text: String
    let author: String
}

final class EmptyStateQuoteProvider: ObservableObject {
    @Published var currentQuote: Quote

    private let quotes: [Quote]

    init() {
        quotes = Self.loadQuotes()
        currentQuote = quotes.randomElement()!
    }

    func randomizeQuote() {
        guard let newQuote = quotes.randomElement() else { return }
        currentQuote = newQuote
    }

    static func loadQuotes() -> [Quote] {
        [
            Quote(text: "Time is what we want most, but\u{00A0}what we use worst", author: "William Penn"),
            Quote(text: "Time stays long enough for\u{00A0}anyone who will use it", author: "Leonardo da Vinci"),
            Quote(text: "Time flies like an arrow; fruit\u{00A0}flies like a banana", author: "Groucho Marx"),
            Quote(text: "Time you enjoy wasting is not wasted time", author: "Marthe Troly-Curtin"),
            Quote(text: "Nothing is a waste of time if you use the experience wisely", author: "Auguste Rodin"),
            Quote(text: "Time is a created thing. To say 'I\u{00A0}don't have time' is to say 'I\u{00A0}don't want to'", author: "Lao Tzu"),
            Quote(text: "Time is the longest distance between two places", author: "Tennessee Williams")
        ]
    }
}
