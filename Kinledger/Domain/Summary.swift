import Foundation

struct Totals: Equatable, Sendable {
    var minutes = 0
    /// Money the caregiver paid and nobody has repaid.
    var outOfPocketCents = 0
    var visits = 0
}

extension Sequence where Element == Entry {
    func totals() -> Totals {
        reduce(into: Totals()) { acc, e in
            acc.minutes += e.minutes
            if let expense = e.expense, expense.payer == .me {
                acc.outOfPocketCents += expense.amountCents
            }
            if e.visit { acc.visits += 1 }
        }
    }

    /// Entries whose care happened in the month that contains `date`.
    func inMonth(of date: Date, calendar: Calendar = .current) -> [Entry] {
        filter { calendar.isDate($0.occurredAt, equalTo: date, toGranularity: .month) }
    }

    /// Newest first.
    func recent(_ limit: Int) -> [Entry] {
        Array(sorted { $0.occurredAt > $1.occurredAt }.prefix(limit))
    }
}
