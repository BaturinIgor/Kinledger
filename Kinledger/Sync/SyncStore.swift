import Foundation
import GRDB

/// What happened when changes from the cloud were applied.
struct ApplyResult: Equatable, Sendable {
    /// Entries written from the cloud copy.
    var applied = 0
    /// Cloud versions skipped because the phone has the same or a newer one.
    var keptLocal = 0
}

/// Sync bookkeeping on top of the local store. The phone stays the source of truth for what the
/// person typed: a newer cloud version replaces a local one only after the local one is kept in history.
extension EntryStore {
    static let cursorKey = "entries.cursor"

    /// Entries changed on this phone since they were last uploaded, oldest change first.
    func pendingEntries(limit: Int = 200) throws -> [CloudEntry] {
        try writer.read { db in
            try EntryRecord
                .filter(Column("syncedAt") == nil || Column("syncedAt") < Column("updatedAt"))
                .order(Column("updatedAt"))
                .limit(limit)
                .fetchAll(db)
                .map { CloudEntry(entry: $0.entry, updatedAt: $0.updatedAt, deletedAt: $0.deletedAt) }
        }
    }

    func pendingCount() throws -> Int {
        try writer.read { db in
            try EntryRecord
                .filter(Column("syncedAt") == nil || Column("syncedAt") < Column("updatedAt"))
                .fetchCount(db)
        }
    }

    /// Marks uploaded entries as synced. An entry edited again while the upload ran stays pending.
    func markSynced(_ items: [CloudEntry]) throws {
        try writer.write { db in
            for item in items {
                _ = try EntryRecord
                    .filter(key: item.id.uuidString)
                    .filter(Column("updatedAt") == item.updatedAt)
                    .updateAll(db, Column("syncedAt").set(to: item.updatedAt))
            }
        }
    }

    /// Applies entries that came from the cloud.
    ///
    /// - The newer change wins, by `updatedAt`.
    /// - A local version that loses is kept in history, so it can be brought back.
    /// - Trash older than `trashDays` is not brought back to a phone that already removed it.
    @discardableResult
    func applyRemote(_ items: [CloudEntry], now: Date = .now) throws -> ApplyResult {
        let cutoff = now.addingTimeInterval(-Double(Self.trashDays) * 24 * 60 * 60)
        return try writer.write { db in
            let encoder = JSONEncoder()
            var result = ApplyResult()
            for remote in items {
                let local = try EntryRecord.fetchOne(db, key: remote.id.uuidString)
                if let local, local.updatedAt >= remote.updatedAt {
                    result.keptLocal += 1
                    continue
                }
                if local == nil, let deletedAt = remote.deletedAt, deletedAt < cutoff {
                    continue
                }
                if let local, local.entry != remote.entry {
                    var revision = EntryRevisionRecord(
                        id: nil,
                        entryId: local.id,
                        savedAt: now,
                        snapshot: try encoder.encode(local.entry)
                    )
                    try revision.insert(db)
                }
                let record = EntryRecord(
                    remote.entry,
                    updatedAt: remote.updatedAt,
                    deletedAt: remote.deletedAt,
                    syncedAt: remote.updatedAt
                )
                try record.save(db)
                result.applied += 1
            }
            return result
        }
    }

    // MARK: Profile

    func pendingProfile() throws -> CloudProfile? {
        try writer.read { db in
            guard let record = try ProfileRecord.fetchOne(db, key: 1) else { return nil }
            if let syncedAt = record.syncedAt, syncedAt >= record.updatedAt { return nil }
            return CloudProfile(profile: record.profile, updatedAt: record.updatedAt)
        }
    }

    func markProfileSynced(_ uploaded: CloudProfile) throws {
        try writer.write { db in
            _ = try ProfileRecord
                .filter(key: 1)
                .filter(Column("updatedAt") == uploaded.updatedAt)
                .updateAll(db, Column("syncedAt").set(to: uploaded.updatedAt))
        }
    }

    /// Takes the cloud profile only when this phone has none or an older one (a new phone after sign-in).
    func applyRemoteProfile(_ remote: CloudProfile) throws {
        try writer.write { db in
            if let local = try ProfileRecord.fetchOne(db, key: 1), local.updatedAt >= remote.updatedAt { return }
            try ProfileRecord(remote.profile, updatedAt: remote.updatedAt, syncedAt: remote.updatedAt).save(db)
        }
    }

    // MARK: Receipts

    /// Receipt files referenced by entries that are not in the cloud yet.
    func receiptsToUpload() throws -> [String] {
        try writer.read { db in
            try String.fetchAll(db, sql: """
                SELECT DISTINCT receiptPath FROM entry
                WHERE receiptPath IS NOT NULL
                  AND receiptPath NOT IN (SELECT name FROM receiptUpload)
                """)
        }
    }

    func markReceiptUploaded(_ name: String, now: Date = .now) throws {
        try writer.write { db in
            try db.execute(
                sql: "INSERT OR REPLACE INTO receiptUpload (name, uploadedAt) VALUES (?, ?)",
                arguments: [name, now]
            )
        }
    }

    /// All receipt file names entries refer to, for finding ones missing on this phone.
    func referencedReceipts() throws -> [String] {
        try writer.read { db in
            try String.fetchAll(db, sql: "SELECT DISTINCT receiptPath FROM entry WHERE receiptPath IS NOT NULL")
        }
    }

    // MARK: Bookkeeping

    func syncValue(_ key: String) throws -> String? {
        try writer.read { db in
            try String.fetchOne(db, sql: "SELECT value FROM syncState WHERE key = ?", arguments: [key])
        }
    }

    func setSyncValue(_ value: String?, for key: String) throws {
        try writer.write { db in
            if let value {
                try db.execute(sql: "INSERT OR REPLACE INTO syncState (key, value) VALUES (?, ?)", arguments: [key, value])
            } else {
                try db.execute(sql: "DELETE FROM syncState WHERE key = ?", arguments: [key])
            }
        }
    }
}
