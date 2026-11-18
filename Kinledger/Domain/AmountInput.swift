import Foundation

/// Parses what the caregiver types into the amount field.
enum AmountInput {
    enum Result: Equatable {
        case empty
        case cents(Int)
        case invalid
        /// A whole number that is probably missing its decimal point: "4280" for $42.80.
        case suspicious(typedCents: Int, suggestedCents: Int)
    }

    /// Whole amounts at or above this many cents are worth a second look.
    static let suspiciousFrom = 100_000

    static func parse(_ text: String) -> Result {
        let cleaned = text
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespaces)
        if cleaned.isEmpty { return .empty }
        guard cleaned.allSatisfy({ "0123456789.".contains($0) }) else { return .invalid }

        let parts = cleaned.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count <= 2, !(parts.count == 2 && parts[1].count > 2) else { return .invalid }
        guard let whole = Int(parts[0].isEmpty ? "0" : String(parts[0])), whole < 10_000_000 else { return .invalid }

        var fraction = 0
        if parts.count == 2, !parts[1].isEmpty {
            let digits = String(parts[1]).padding(toLength: 2, withPad: "0", startingAt: 0)
            fraction = Int(digits) ?? 0
        }
        let cents = whole * 100 + fraction
        // "1,140" was typed on purpose; "4280" with no point probably means 42.80.
        if parts.count == 1 && !text.contains(",") && cents >= suspiciousFrom {
            return .suspicious(typedCents: cents, suggestedCents: whole)
        }
        return .cents(cents)
    }

    /// The text to show for an amount in the field: 4280 → "42.80", 1800 → "18".
    static func text(cents: Int) -> String {
        cents % 100 == 0 ? "\(cents / 100)" : String(format: "%d.%02d", cents / 100, cents % 100)
    }
}
