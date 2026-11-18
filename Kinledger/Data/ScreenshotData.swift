import Foundation

/// A believable month for the App Store screenshots, in the phone's language and currency.
/// The app uses it only when launched with `-screenshots` (see KinledgerUITests).
enum ScreenshotData {
    static let launchArgument = "-screenshots"

    static var isActive: Bool { ProcessInfo.processInfo.arguments.contains(launchArgument) }

    /// Roughly how many of the local currency make one US dollar, so amounts look ordinary.
    static func scale(for currency: String) -> Double {
        switch currency {
        case "JPY": 150
        case "KRW": 1400
        case "CNY": 7
        case "TWD": 32
        case "SEK", "NOK": 10
        case "DKK": 7
        case "PLN": 4
        case "RUB": 90
        case "UAH": 40
        case "TRY": 35
        case "BRL": 5
        default: 1
        }
    }

    static func profile(locale: Locale = .current) -> CareProfile {
        let country = Country.guess(for: locale)
        return CareProfile(
            parentName: String(localized: "Margaret"),
            nickname: String(localized: "Mom"),
            country: country,
            currency: country == .other ? locale.currency?.identifier : nil
        )
    }

    static func entries(currency: String, now: Date = .now, calendar: Calendar = .current) -> [Entry] {
        let factor = scale(for: currency)
        func money(_ cents: Int) -> Int {
            factor == 1 ? cents : Int((Double(cents) * factor / 100).rounded()) * 100
        }
        // Spread the month's entries over the days that have passed, newest first.
        let monthStart = calendar.dateInterval(of: .month, for: now)?.start ?? now
        let span = max(now.timeIntervalSince(monthStart) - 3600, 3600)
        let items: [(EntryCategory, String, Int, Bool, Int?, Payer, Bool, String?)] = [
            (.pharmacy, String(localized: "Pharmacy pickup"), 25, false, 4280, .me, true, nil),
            (.doctor, String(localized: "Cardiology check-up"), 130, true, 1800, .me, true, String(localized: "Drove her. New dose from Monday.")),
            (.overnight, String(localized: "Overnight stay"), 540, true, nil, .me, false, String(localized: "After a fall. She's OK.")),
            (.groceries, String(localized: "Groceries"), 60, true, 6715, .parent, false, nil),
            (.bills, String(localized: "Electric bill and a call with the bank"), 40, false, 11240, .me, false, nil),
            (.homeHelp, String(localized: "Cleaning and laundry"), 120, true, nil, .me, false, nil),
            (.transport, String(localized: "Taxi to physiotherapy"), 90, true, 2350, .me, true, nil),
            (.pharmacy, String(localized: "Weekly pill organizer"), 20, true, 1290, .me, true, nil),
            (.groceries, String(localized: "Groceries"), 45, true, 5430, .me, false, nil),
            (.other, String(localized: "Lunch together"), 75, true, 2600, .me, false, nil),
        ]
        return items.enumerated().map { index, item in
            let occurred = now.addingTimeInterval(-span * Double(index) / Double(items.count) - 3600)
            return Entry(
                id: UUID(),
                category: item.0,
                title: item.1,
                occurredAt: occurred,
                loggedAt: occurred.addingTimeInterval(Double(item.2 * 60 + 600)),
                minutes: item.2,
                visit: item.3,
                expense: item.4.map { Expense(amountCents: money($0), payer: item.5, medical: item.6) },
                note: item.7
            )
        }
    }
}

extension AppModel {
    /// The app as the screenshots show it: onboarded, one month of care, one brother on the report.
    static func screenshots() -> AppModel {
        let store = try! EntryStore.inMemory()
        let profile = ScreenshotData.profile()
        try? store.saveProfile(profile)
        try? store.saveRecipient(Recipient(id: UUID(), name: String(localized: "Dave"), contact: "dave@example.com", relation: "Brother"))
        for entry in ScreenshotData.entries(currency: profile.currencyCode) { try? store.save(entry) }
        return AppModel(store: store, receipts: try! ReceiptStore.temporary())
    }
}
