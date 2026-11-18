import Foundation

/// Who paid for an expense. Drives the "out of pocket" total in the report (R4).
enum Payer: String, Codable, Sendable, CaseIterable {
    case me
    case parent
    case repaid
}

enum EntryCategory: String, Codable, Sendable, CaseIterable {
    case doctor
    case pharmacy
    case groceries
    case overnight
    case bills
    case homeHelp = "home-help"
    case transport
    case other
}

struct Expense: Codable, Sendable, Hashable {
    /// Integer cents, never floating point.
    var amountCents: Int
    var payer: Payer
    /// Counts toward the US medical-expense export (R14).
    var medical: Bool
    var receiptPath: String?
}

struct Entry: Identifiable, Codable, Sendable, Hashable {
    /// Generated on the device, so a retried upload never creates a duplicate.
    var id: UUID
    var category: EntryCategory
    var title: String
    /// When the care happened.
    var occurredAt: Date
    /// When it was logged. Shown in the report as evidence (R9).
    var loggedAt: Date
    var minutes: Int
    /// A visit counts once toward the visits total.
    var visit: Bool
    var expense: Expense?
    /// Private by default; the caregiver chooses to include notes in a report (R7).
    var note: String?
}
