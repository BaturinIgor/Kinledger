import Foundation
import GRDB

/// One row of the `entry` table. The domain `Entry` stays free of database details.
struct EntryRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "entry"

    var id: String
    var category: String
    var title: String
    var occurredAt: Date
    var loggedAt: Date
    var updatedAt: Date
    var minutes: Int
    var visit: Bool
    var amountCents: Int?
    var payer: String?
    var medical: Bool
    var receiptPath: String?
    var note: String?
    /// Set when the entry is in the trash. Rows are only removed 30 days later.
    var deletedAt: Date?

    init(_ entry: Entry, updatedAt: Date, deletedAt: Date? = nil) {
        id = entry.id.uuidString
        category = entry.category.rawValue
        title = entry.title
        occurredAt = entry.occurredAt
        loggedAt = entry.loggedAt
        self.updatedAt = updatedAt
        minutes = entry.minutes
        visit = entry.visit
        amountCents = entry.expense?.amountCents
        payer = entry.expense?.payer.rawValue
        medical = entry.expense?.medical ?? false
        receiptPath = entry.expense?.receiptPath
        note = entry.note
        self.deletedAt = deletedAt
    }

    var entry: Entry {
        Entry(
            id: UUID(uuidString: id) ?? UUID(),
            category: EntryCategory(rawValue: category) ?? .other,
            title: title,
            occurredAt: occurredAt,
            loggedAt: loggedAt,
            minutes: minutes,
            visit: visit,
            expense: amountCents.map {
                Expense(
                    amountCents: $0,
                    payer: Payer(rawValue: payer ?? "") ?? .me,
                    medical: medical,
                    receiptPath: receiptPath
                )
            },
            note: note
        )
    }
}

/// A previous version of an entry, written every time the entry changes.
struct EntryRevisionRecord: Codable, FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "entryRevision"

    var id: Int64?
    var entryId: String
    var savedAt: Date
    /// The entry as it was before the change, as JSON.
    var snapshot: Data

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
