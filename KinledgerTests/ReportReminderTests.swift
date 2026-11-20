import Foundation
import Testing
@testable import Kinledger

/// The reminder comes on the 1st at 10:00 about the month before, and only when that month has entries (R8).
struct ReportReminderTests {
    var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/New_York")!
        return c
    }()

    func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    func entry(on day: Date) -> Entry {
        Entry(id: UUID(), category: .doctor, title: "Visit", occurredAt: day, loggedAt: day,
              minutes: 60, visit: true, expense: nil, note: nil)
    }

    @Test func midMonthFiresOnTheNextFirst() {
        #expect(ReportReminder.nextFireDate(after: date(2026, 11, 20, 15), calendar: calendar) == date(2026, 12, 1, 10))
    }

    @Test func earlyOnTheFirstFiresTheSameDay() {
        #expect(ReportReminder.nextFireDate(after: date(2026, 12, 1, 8), calendar: calendar) == date(2026, 12, 1, 10))
    }

    @Test func afterTenOnTheFirstWaitsAMonth() {
        #expect(ReportReminder.nextFireDate(after: date(2026, 12, 1, 10), calendar: calendar) == date(2027, 1, 1, 10))
    }

    @Test func decemberRollsIntoJanuary() {
        let fire = ReportReminder.nextFireDate(after: date(2026, 12, 31, 23, 59), calendar: calendar)
        #expect(fire == date(2027, 1, 1, 10))
        #expect(ReportReminder.reportMonth(for: fire, calendar: calendar) == date(2026, 12, 1))
    }

    @Test func remindsOnlyWhenTheMonthHasEntries() {
        let fire = date(2026, 12, 1, 10)
        #expect(!ReportReminder.shouldSchedule(entries: [], fireDate: fire, calendar: calendar))
        #expect(!ReportReminder.shouldSchedule(entries: [entry(on: date(2026, 10, 30))], fireDate: fire, calendar: calendar))
        #expect(ReportReminder.shouldSchedule(entries: [entry(on: date(2026, 11, 18, 12))], fireDate: fire, calendar: calendar))
    }
}
