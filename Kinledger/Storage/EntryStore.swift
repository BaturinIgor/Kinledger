import Foundation
import GRDB

struct EntryRevision: Identifiable, Hashable, Sendable {
    let id: Int64
    /// When the entry was changed away from this version.
    let replacedAt: Date
    let previous: Entry
}

struct TrashedEntry: Identifiable, Hashable, Sendable {
    var id: UUID { entry.id }
    let entry: Entry
    let deletedAt: Date
}

/// Local, durable storage for entries. Every write lands in SQLite before anything else happens.
///
/// Data-safety rules (docs/data-safety.md):
/// - Deleting moves an entry to the trash; rows are removed only after `trashDays`.
/// - Every change keeps the previous version in `entryRevision`.
/// - Schema changes are numbered migrations, and the file is copied before migrating.
final class EntryStore: Sendable {
    static let trashDays = 30
    static let fileName = "kinledger.sqlite"
    static let preMigrationCopyName = "kinledger-before-migration.sqlite"

    let writer: any DatabaseWriter

    init(writer: any DatabaseWriter) throws {
        self.writer = writer
        try Self.migrator.migrate(writer)
    }

    /// A throwaway store for tests and previews.
    static func inMemory() throws -> EntryStore {
        try EntryStore(writer: DatabaseQueue())
    }

    /// The app's store in Application Support, which iOS includes in device backups.
    static func onDisk(directory: URL = URL.applicationSupportDirectory) throws -> EntryStore {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appending(path: Self.fileName)
        let queue = try DatabaseQueue(path: file.path)
        try copyBeforeMigrating(queue, file: file)
        return try EntryStore(writer: queue)
    }

    // MARK: Schema

    static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1") { db in
            try db.create(table: "entry") { t in
                t.primaryKey("id", .text)
                t.column("category", .text).notNull()
                t.column("title", .text).notNull()
                t.column("occurredAt", .datetime).notNull().indexed()
                t.column("loggedAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
                t.column("minutes", .integer).notNull()
                t.column("visit", .boolean).notNull()
                t.column("amountCents", .integer)
                t.column("payer", .text)
                t.column("medical", .boolean).notNull().defaults(to: false)
                t.column("receiptPath", .text)
                t.column("note", .text)
                t.column("deletedAt", .datetime)
            }
            try db.create(table: "entryRevision") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("entryId", .text).notNull().indexed()
                t.column("savedAt", .datetime).notNull()
                t.column("snapshot", .blob).notNull()
            }
        }
        migrator.registerMigration("v2-profile") { db in
            try db.create(table: "profile") { t in
                t.primaryKey("id", .integer)
                t.column("parentName", .text).notNull()
                t.column("nickname", .text).notNull()
                t.column("country", .text).notNull()
                t.column("updatedAt", .datetime).notNull()
            }
            try db.create(table: "recipient") { t in
                t.primaryKey("id", .text)
                t.column("name", .text).notNull()
                t.column("contact", .text).notNull()
                t.column("relation", .text).notNull()
                t.column("createdAt", .datetime).notNull()
            }
        }
        return migrator
    }

    /// Keeps a copy of the database before a migration touches existing data.
    static func copyBeforeMigrating(_ queue: DatabaseQueue, file: URL) throws {
        let needsCopy = try queue.read { db -> Bool in
            guard try db.tableExists("entry") else { return false }
            return try !migrator.hasCompletedMigrations(db)
        }
        guard needsCopy else { return }
        let copyURL = file.deletingLastPathComponent().appending(path: preMigrationCopyName)
        try? FileManager.default.removeItem(at: copyURL)
        let copy = try DatabaseQueue(path: copyURL.path)
        try queue.backup(to: copy)
    }

    // MARK: Reading

    /// Entries not in the trash, newest care first.
    func entries() throws -> [Entry] {
        try writer.read { db in
            try EntryRecord
                .filter(Column("deletedAt") == nil)
                .order(Column("occurredAt").desc)
                .fetchAll(db)
                .map(\.entry)
        }
    }

    func trash() throws -> [TrashedEntry] {
        try writer.read { db in
            try EntryRecord
                .filter(Column("deletedAt") != nil)
                .order(Column("deletedAt").desc)
                .fetchAll(db)
                .compactMap { record in
                    record.deletedAt.map { TrashedEntry(entry: record.entry, deletedAt: $0) }
                }
        }
    }

    /// Earlier versions of an entry, most recent change first.
    func history(of id: UUID) throws -> [EntryRevision] {
        try writer.read { db in
            let decoder = JSONDecoder()
            return try EntryRevisionRecord
                .filter(Column("entryId") == id.uuidString)
                .order(Column("savedAt").desc, Column("id").desc)
                .fetchAll(db)
                .compactMap { record in
                    guard let rowID = record.id,
                          let previous = try? decoder.decode(Entry.self, from: record.snapshot)
                    else { return nil }
                    return EntryRevision(id: rowID, replacedAt: record.savedAt, previous: previous)
                }
        }
    }

    // MARK: Writing

    /// Inserts a new entry or updates an existing one. An update keeps the old version in history.
    func save(_ entry: Entry, now: Date = .now) throws {
        try writer.write { db in
            let encoder = JSONEncoder()
            let existing = try EntryRecord.fetchOne(db, key: entry.id.uuidString)
            if let existing {
                let old = existing.entry
                guard old != entry else { return }
                var revision = EntryRevisionRecord(
                    id: nil,
                    entryId: existing.id,
                    savedAt: now,
                    snapshot: try encoder.encode(old)
                )
                try revision.insert(db)
            }
            let record = EntryRecord(entry, updatedAt: now, deletedAt: existing?.deletedAt)
            try record.save(db)
        }
    }

    func moveToTrash(_ id: UUID, now: Date = .now) throws {
        try writer.write { db in
            _ = try EntryRecord
                .filter(key: id.uuidString)
                .updateAll(db, Column("deletedAt").set(to: now), Column("updatedAt").set(to: now))
        }
    }

    func restoreFromTrash(_ id: UUID, now: Date = .now) throws {
        try writer.write { db in
            _ = try EntryRecord
                .filter(key: id.uuidString)
                .updateAll(db, Column("deletedAt").set(to: nil), Column("updatedAt").set(to: now))
        }
    }

    /// Brings back an earlier version. The version being replaced goes into history too.
    func restore(_ revision: EntryRevision, now: Date = .now) throws {
        try save(revision.previous, now: now)
    }

    /// Removes entries that have been in the trash longer than `trashDays`.
    /// Returns the receipt files those entries used, so the caller can delete them too.
    @discardableResult
    func purgeExpiredTrash(now: Date = .now) throws -> PurgeResult {
        let cutoff = now.addingTimeInterval(-Double(Self.trashDays) * 24 * 60 * 60)
        return try writer.write { db in
            let expired = try EntryRecord
                .filter(Column("deletedAt") != nil && Column("deletedAt") < cutoff)
                .fetchAll(db)
            guard !expired.isEmpty else { return PurgeResult(count: 0, receiptFiles: []) }
            let ids = expired.map(\.id)
            _ = try EntryRevisionRecord.filter(ids.contains(Column("entryId"))).deleteAll(db)
            let count = try EntryRecord.deleteAll(db, keys: ids)
            return PurgeResult(count: count, receiptFiles: expired.compactMap(\.receiptPath))
        }
    }
}

struct PurgeResult: Equatable, Sendable {
    let count: Int
    let receiptFiles: [String]
}
