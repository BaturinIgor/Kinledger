import Foundation

/// What the monthly report shows (R6–R8). Built from entries only, so it is easy to test.
struct MonthReport: Sendable {
    let month: Date
    let entries: [Entry]
    let totals: Totals
    /// Money the caregiver paid, by category, largest first.
    let spending: [CategoryAmount]
    let receiptCount: Int

    struct CategoryAmount: Hashable, Sendable {
        let category: EntryCategory
        let cents: Int
    }

    init(entries all: [Entry], month: Date, calendar: Calendar = .current) {
        self.month = month
        entries = all.inMonth(of: month, calendar: calendar).sorted { $0.occurredAt < $1.occurredAt }
        totals = entries.totals()
        var byCategory: [EntryCategory: Int] = [:]
        for entry in entries {
            if let expense = entry.expense, expense.payer == .me {
                byCategory[entry.category, default: 0] += expense.amountCents
            }
        }
        spending = byCategory
            .map { CategoryAmount(category: $0.key, cents: $0.value) }
            .sorted { $0.cents == $1.cents ? $0.category.label < $1.category.label : $0.cents > $1.cents }
        receiptCount = entries.filter { $0.expense?.receiptPath != nil }.count
    }

    /// "You spent 52 h with Mom, visited 14 times and paid $1,140 yourself."
    func headline(parentName: String, money format: (Int) -> String = { Format.money(cents: $0) }) -> String {
        let hours = Format.durationSummary(minutes: totals.minutes)
        let visits = totals.visits == 1 ? String(localized: "once") : String(localized: "\(totals.visits) times")
        let money = format(totals.outOfPocketCents)
        return String(localized: "You spent \(hours) with \(parentName), visited \(visits) and paid \(money) yourself.")
    }
}

/// US medical-expense summary for one tax year (R14): what the caregiver paid and marked medical.
struct TaxYearSummary: Sendable {
    let year: Int
    let expenses: [Entry]
    let totalCents: Int
    let withReceipt: Int
    var withoutReceipt: Int { expenses.count - withReceipt }

    init(entries: [Entry], year: Int, calendar: Calendar = .current) {
        self.year = year
        expenses = entries
            .filter { entry in
                guard let expense = entry.expense else { return false }
                return expense.medical && expense.payer == .me
                    && calendar.component(.year, from: entry.occurredAt) == year
            }
            .sorted { $0.occurredAt < $1.occurredAt }
        totalCents = expenses.reduce(0) { $0 + ($1.expense?.amountCents ?? 0) }
        withReceipt = expenses.filter { $0.expense?.receiptPath != nil }.count
    }
}

/// Comma-separated values that open cleanly in Excel, Numbers and Google Sheets.
enum CSV {
    static func field(_ value: String) -> String {
        var text = value
        // A cell starting with these can run as a formula in a spreadsheet.
        if let first = text.first, "=+-@".contains(first) { text = "'" + text }
        if text.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }) {
            return "\"" + text.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return text
    }

    static func line(_ fields: [String]) -> String {
        fields.map(field).joined(separator: ",")
    }

    static func document(header: [String], rows: [[String]]) -> String {
        ([header] + rows).map(line).joined(separator: "\r\n") + "\r\n"
    }

    /// Always two decimals, no currency sign: 4280 → "42.80".
    static func amount(_ cents: Int) -> String {
        String(format: "%d.%02d", cents / 100, cents % 100)
    }

    static func date(_ date: Date, timeZone: TimeZone = .current) -> String {
        date.formatted(Date.ISO8601FormatStyle(timeZone: timeZone).year().month().day())
    }

    static func dateTime(_ date: Date, timeZone: TimeZone = .current) -> String {
        date.formatted(Date.ISO8601FormatStyle(timeZone: timeZone))
    }

    /// Every entry, for "Export all my data". Nothing is left out, notes included.
    static func allEntries(_ entries: [Entry], timeZone: TimeZone = .current) -> String {
        document(
            header: ["id", "occurred_at", "logged_at", "category", "title", "minutes", "visit",
                     "amount", "payer", "medical", "receipt_file", "note"],
            rows: entries.sorted { $0.occurredAt < $1.occurredAt }.map { e in
                [
                    e.id.uuidString,
                    dateTime(e.occurredAt, timeZone: timeZone),
                    dateTime(e.loggedAt, timeZone: timeZone),
                    e.category.rawValue,
                    e.title,
                    String(e.minutes),
                    e.visit ? "yes" : "no",
                    e.expense.map { amount($0.amountCents) } ?? "",
                    e.expense?.payer.rawValue ?? "",
                    e.expense.map { $0.medical ? "yes" : "no" } ?? "",
                    e.expense?.receiptPath.map { "receipts/\($0)" } ?? "",
                    e.note ?? "",
                ]
            }
        )
    }

    /// One row per medical expense, for a tax preparer.
    static func taxYear(_ summary: TaxYearSummary, timeZone: TimeZone = .current) -> String {
        document(
            header: ["date", "description", "category", "amount_usd", "receipt_file"],
            rows: summary.expenses.map { e in
                [
                    date(e.occurredAt, timeZone: timeZone),
                    e.title,
                    e.category.label,
                    amount(e.expense?.amountCents ?? 0),
                    e.expense?.receiptPath.map { "receipts/\($0)" } ?? "no receipt",
                ]
            }
        )
    }
}
