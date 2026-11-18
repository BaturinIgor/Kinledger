import Foundation

enum Format {
    /// 25 → "25 min", 130 → "2 h 10 min", 120 → "2 h".
    static func duration(minutes: Int) -> String {
        if minutes < 60 { return "\(minutes) min" }
        let h = minutes / 60
        let m = minutes % 60
        return m == 0 ? "\(h) h" : "\(h) h \(m) min"
    }

    /// Month totals round to half hours: 0 → "0 h", 1890 → "31.5 h".
    static func durationSummary(minutes: Int) -> String {
        let halfHours = (Double(minutes) / 30).rounded() / 2
        let isWhole = halfHours == halfHours.rounded()
        return isWhole ? "\(Int(halfHours)) h" : String(format: "%.1f h", halfHours)
    }

    /// 4280 → "$42.80", 1800 → "$18". Whole amounts drop the cents.
    static func money(cents: Int, currency: String = "USD", locale: Locale = Locale(identifier: "en_US")) -> String {
        let amount = Decimal(cents) / 100
        let digits = cents % 100 == 0 ? 0 : 2
        return amount.formatted(
            .currency(code: currency)
                .precision(.fractionLength(digits))
                .locale(locale)
        )
    }
}
