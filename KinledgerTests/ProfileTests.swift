import Foundation
import GRDB
import Testing
@testable import Kinledger

struct ProfileTests {
    @Test func profileAndRecipientsRoundTrip() throws {
        let store = try EntryStore.inMemory()
        #expect(try store.profile() == nil)

        let profile = CareProfile(parentName: "Margaret", nickname: "Mom", country: .uk)
        try store.saveProfile(profile)
        #expect(try store.profile() == profile)

        let dave = Recipient(id: UUID(), name: "Dave", contact: "dave@example.com", relation: "Brother")
        try store.saveRecipient(dave)
        #expect(try store.recipients() == [dave])
        try store.deleteRecipient(dave.id)
        #expect(try store.recipients().isEmpty)
    }

    @Test func moneyFollowsTheCountry() {
        #expect(CareProfile(parentName: "M", nickname: "Mom", country: .us).money(4280) == "$42.80")
        #expect(CareProfile(parentName: "M", nickname: "Mum", country: .uk).money(4280) == "£42.80")
    }

    @Test func countryIsGuessedFromThePhoneRegion() {
        #expect(Country.guess(for: Locale(identifier: "en_US")) == .us)
        #expect(Country.guess(for: Locale(identifier: "en_GB")) == .uk)
        #expect(Country.guess(for: Locale(identifier: "fr_CA")) == .canada)
        #expect(Country.guess(for: Locale(identifier: "en_AU")) == .australia)
        #expect(Country.guess(for: Locale(identifier: "de_DE")) == .europe)
        #expect(Country.guess(for: Locale(identifier: "ja_JP")) == .other)
        #expect(Country.guess(for: Locale(identifier: "en")) == .other)
    }

    @Test func anotherCountryKeepsItsOwnCurrency() throws {
        let store = try EntryStore.inMemory()
        let profile = CareProfile(parentName: "Haruko", nickname: "Okaasan", country: .other, currency: "JPY")
        try store.saveProfile(profile)
        let saved = try #require(try store.profile())
        #expect(saved.currencyCode == "JPY")
        #expect(saved.money(428_000, locale: Locale(identifier: "en_US")) == "¥4,280")
        #expect(CareProfile(parentName: "M", nickname: "Mom", country: .uk).currencyCode == "GBP")
    }

    @Test func relationsAreStoredInEnglishAndShownLocalized() {
        let dave = Recipient(id: UUID(), name: "Dave", contact: "", relation: "Brother")
        #expect(Recipient.relations.contains(dave.relation))
        #expect(!dave.relationLabel.isEmpty)
        #expect(Recipient.label(forRelation: "Cousin") == "Cousin")
    }

    /// Release-blocking scenario 7: an update must not lose existing entries.
    @Test func upgradingAVersionOneDatabaseKeepsEntriesAndMakesACopy() throws {
        let dir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appending(path: EntryStore.fileName)

        // A database as version 1 of the app left it, with 500 entries.
        let entries = (0..<500).map { i in
            Entry(id: UUID(), category: .groceries, title: "Groceries \(i)",
                  occurredAt: SampleData.month.addingTimeInterval(Double(-i) * 3600),
                  loggedAt: SampleData.month, minutes: 30, visit: true,
                  expense: Expense(amountCents: 1000 + i, payer: .me, medical: false), note: nil)
        }
        do {
            let old = try DatabaseQueue(path: file.path)
            try EntryStore.migrator.migrate(old, upTo: "v1")
            try old.write { db in
                // Raw SQL with the version 1 columns, so later fields on EntryRecord never change this test.
                for e in entries {
                    try db.execute(
                        sql: """
                            INSERT INTO entry (id, category, title, occurredAt, loggedAt, updatedAt, minutes, visit,
                                               amountCents, payer, medical, receiptPath, note, deletedAt)
                            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL, NULL, NULL)
                            """,
                        arguments: [e.id.uuidString, e.category.rawValue, e.title, e.occurredAt, e.loggedAt,
                                    SampleData.month, e.minutes, e.visit, e.expense?.amountCents,
                                    e.expense?.payer.rawValue, e.expense?.medical ?? false]
                    )
                }
            }
        }

        let upgraded = try EntryStore.onDisk(directory: dir)
        #expect(try upgraded.entries().count == 500)
        #expect(try upgraded.entries().sorted { $0.title < $1.title } == entries.sorted { $0.title < $1.title })
        // Everything from before cloud backup is waiting to upload.
        #expect(try upgraded.pendingCount() == 500)
        #expect(try upgraded.profile() == nil)
        #expect(FileManager.default.fileExists(atPath: dir.appending(path: EntryStore.preMigrationCopyName).path))
    }
}

struct ProTests {
    @Test func yearlyPlanSavesAThird() {
        #expect(Pricing.yearlySavingsPercent(monthly: Decimal(string: "9.99")!, yearly: 79) == 34)
        #expect(Pricing.yearlySavingsPercent(monthly: 10, yearly: 200) == 0)
    }

    @Test func eitherPlanUnlocksPro() {
        #expect(ProStore.unlocks([ProStore.monthlyID]))
        #expect(ProStore.unlocks([ProStore.yearlyID]))
        #expect(!ProStore.unlocks([]))
        #expect(!ProStore.unlocks(["something.else"]))
    }
}
