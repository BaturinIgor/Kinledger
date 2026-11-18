import Foundation
import GRDB

struct ProfileRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "profile"
    /// A single row; the table exists so the profile is backed up and exported like everything else.
    var id: Int = 1
    var parentName: String
    var nickname: String
    var country: String
    var updatedAt: Date
    var syncedAt: Date?
    var currency: String?

    init(_ profile: CareProfile, updatedAt: Date, syncedAt: Date? = nil) {
        currency = profile.currency
        parentName = profile.parentName
        nickname = profile.nickname
        country = profile.country.rawValue
        self.updatedAt = updatedAt
        self.syncedAt = syncedAt
    }

    var profile: CareProfile {
        CareProfile(parentName: parentName, nickname: nickname, country: Country(rawValue: country) ?? .us, currency: currency)
    }
}

struct RecipientRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "recipient"
    var id: String
    var name: String
    var contact: String
    var relation: String
    var createdAt: Date

    init(_ recipient: Recipient, createdAt: Date) {
        id = recipient.id.uuidString
        name = recipient.name
        contact = recipient.contact
        relation = recipient.relation
        self.createdAt = createdAt
    }

    var recipient: Recipient {
        Recipient(id: UUID(uuidString: id) ?? UUID(), name: name, contact: contact, relation: relation)
    }
}

extension EntryStore {
    func profile() throws -> CareProfile? {
        try writer.read { db in try ProfileRecord.fetchOne(db, key: 1)?.profile }
    }

    func saveProfile(_ profile: CareProfile, now: Date = .now) throws {
        try writer.write { db in try ProfileRecord(profile, updatedAt: now).save(db) }
    }

    func recipients() throws -> [Recipient] {
        try writer.read { db in
            try RecipientRecord.order(Column("createdAt")).fetchAll(db).map(\.recipient)
        }
    }

    func saveRecipient(_ recipient: Recipient, now: Date = .now) throws {
        try writer.write { db in
            let createdAt = try RecipientRecord.fetchOne(db, key: recipient.id.uuidString)?.createdAt ?? now
            try RecipientRecord(recipient, createdAt: createdAt).save(db)
        }
    }

    func deleteRecipient(_ id: UUID) throws {
        try writer.write { db in _ = try RecipientRecord.deleteOne(db, key: id.uuidString) }
    }
}
