import Foundation

/// Sample data matching the mockups (November 2026), until local storage lands.
enum SampleData {
    static let month = date(2026, 11, 18, 12, 0)

    static let entries: [Entry] = [
        Entry(
            id: UUID(),
            category: .pharmacy,
            title: "Pharmacy pickup",
            occurredAt: date(2026, 11, 18, 15, 0),
            loggedAt: date(2026, 11, 18, 15, 12),
            minutes: 25,
            visit: false,
            expense: Expense(amountCents: 4280, payer: .me, medical: true),
            note: "Receipt saved"
        ),
        Entry(
            id: UUID(),
            category: .doctor,
            title: "Dr. Patel, cardiology",
            occurredAt: date(2026, 11, 16, 10, 0),
            loggedAt: date(2026, 11, 16, 12, 30),
            minutes: 130,
            visit: true,
            expense: Expense(amountCents: 1800, payer: .me, medical: true),
            note: "Drove her"
        ),
        Entry(
            id: UUID(),
            category: .overnight,
            title: "Overnight stay",
            occurredAt: date(2026, 11, 15, 22, 30),
            loggedAt: date(2026, 11, 16, 7, 40),
            minutes: 540,
            visit: true,
            note: "After a fall, she's OK"
        ),
        Entry(
            id: UUID(),
            category: .groceries,
            title: "Groceries",
            occurredAt: date(2026, 11, 14, 11, 0),
            loggedAt: date(2026, 11, 14, 12, 5),
            minutes: 60,
            visit: true,
            expense: Expense(amountCents: 6715, payer: .parent, medical: false)
        ),
    ]

    static func date(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi))!
    }
}
