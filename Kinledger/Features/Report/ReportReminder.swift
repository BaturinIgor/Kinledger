import Foundation
import Observation
import UserNotifications

/// When the monthly reminder fires and which month it is about (R8). Pure, so it is easy to test.
enum ReportReminder {
    static let hour = 10
    static let requestID = "monthly-report"

    /// The next 1st of a month at 10:00 strictly after `now`.
    static func nextFireDate(after now: Date, calendar: Calendar = .current) -> Date {
        let thisMonth = calendar.startOfMonth(for: now)
        let thisFire = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: thisMonth)!
        if thisFire > now { return thisFire }
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: thisMonth)!
        return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: nextMonth)!
    }

    /// The reminder on the 1st is about the month before it.
    static func reportMonth(for fireDate: Date, calendar: Calendar = .current) -> Date {
        let month = calendar.startOfMonth(for: fireDate)
        return calendar.date(byAdding: .month, value: -1, to: month)!
    }

    /// Schedule only when that month already has entries: an empty report is not worth a nudge.
    static func shouldSchedule(entries: [Entry], fireDate: Date, calendar: Calendar = .current) -> Bool {
        !entries.inMonth(of: reportMonth(for: fireDate, calendar: calendar), calendar: calendar).isEmpty
    }
}

/// Schedules the local reminder and opens the report when it is tapped.
/// The report itself is never sent automatically: the notification only opens the preview.
@MainActor @Observable
final class ReportReminderCenter: NSObject {
    static let shared = ReportReminderCenter()

    private static let onKey = "reportReminder.on"
    private static let askedKey = "reportReminder.asked"

    /// Set when a reminder is tapped; the Report tab shows this month and clears it.
    var openMonth: Date?

    var isOn: Bool {
        didSet { UserDefaults.standard.set(isOn, forKey: Self.onKey) }
    }

    override init() {
        isOn = UserDefaults.standard.bool(forKey: Self.onKey)
        super.init()
    }

    func start() {
        UNUserNotificationCenter.current().delegate = self
    }

    /// After the first report is shared: ask once, so the question comes when it makes sense.
    func askAfterFirstShare(entries: [Entry]) async {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: Self.askedKey) else { return }
        defaults.set(true, forKey: Self.askedKey)
        await turnOn(entries: entries)
    }

    /// The switch in Me. Returns false when iOS notifications are off for Kinledger.
    @discardableResult
    func turnOn(entries: [Entry]) async -> Bool {
        let granted = (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])) ?? false
        isOn = granted
        await reschedule(entries: entries)
        return granted
    }

    func turnOff() {
        isOn = false
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [ReportReminder.requestID])
    }

    /// Keeps exactly one pending reminder, for the next 1st, or none.
    func reschedule(entries: [Entry], now: Date = .now) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [ReportReminder.requestID])
        let fire = ReportReminder.nextFireDate(after: now)
        guard isOn, ReportReminder.shouldSchedule(entries: entries, fireDate: fire) else { return }

        let month = ReportReminder.reportMonth(for: fire)
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Monthly report")
        content.body = String(localized: "Your report for \(month.formatted(.dateTime.month(.wide))) is ready. Send it to your family?")
        content.sound = .default
        content.userInfo = ["month": month.ISO8601Format()]

        let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
        let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
        try? await center.add(UNNotificationRequest(identifier: ReportReminder.requestID, content: content, trigger: trigger))
    }
}

extension ReportReminderCenter: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse) async {
        let text = response.notification.request.content.userInfo["month"] as? String
        let month = text.flatMap { try? Date($0, strategy: .iso8601) }
        await MainActor.run { openMonth = month ?? ReportReminder.reportMonth(for: .now) }
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
