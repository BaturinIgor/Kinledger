import Foundation
import GRDB
import Testing
@testable import Kinledger

/// Data-safety rules from docs/data-safety.md, checked against a real SQLite database.
struct StorageTests {
    let t0 = SampleData.date(2026, 11, 18, 15, 0)

    func entry(minutes: Int = 25, cents: Int? = 4280) -> Entry {
        Entry(
            id: UUID(),
            category: .pharmacy,
            title: "Pharmacy pickup",
            occurredAt: t0,
            loggedAt: t0,
            minutes: minutes,
            visit: false,
            expense: cents.map { Expense(amountCents: $0, payer: .me, medical: true) },
            note: "Receipt saved"
        )
    }

    @Test func savedEntryReadsBackUnchanged() throws {
        let store = try EntryStore.inMemory()
        let e = entry()
        try store.save(e)
        #expect(try store.entries() == [e])
    }

    @Test func editKeepsPreviousVersion() throws {
        let store = try EntryStore.inMemory()
        var e = entry()
        try store.save(e, now: t0)
        e.expense?.amountCents = 4500
        try store.save(e, now: t0.addingTimeInterval(60))

        let history = try store.history(of: e.id)
        #expect(history.count == 1)
        #expect(history[0].previous.expense?.amountCents == 4280)
        #expect(try store.entries().first?.expense?.amountCents == 4500)
    }

    @Test func savingTheSameEntryAddsNoHistory() throws {
        let store = try EntryStore.inMemory()
        let e = entry()
        try store.save(e)
        try store.save(e)
        #expect(try store.history(of: e.id).isEmpty)
    }

    @Test func restoringAVersionKeepsTheReplacedOne() throws {
        let store = try EntryStore.inMemory()
        var e = entry()
        try store.save(e, now: t0)
        e.minutes = 40
        try store.save(e, now: t0.addingTimeInterval(60))
        let old = try #require(try store.history(of: e.id).first)
        try store.restore(old, now: t0.addingTimeInterval(120))

        #expect(try store.entries().first?.minutes == 25)
        #expect(try store.history(of: e.id).count == 2)
    }

    @Test func deleteMovesToTrashAndRestoreBringsItBack() throws {
        let store = try EntryStore.inMemory()
        let e = entry()
        try store.save(e)
        try store.moveToTrash(e.id, now: t0)

        #expect(try store.entries().isEmpty)
        #expect(try store.trash().map(\.entry) == [e])

        try store.restoreFromTrash(e.id)
        #expect(try store.entries() == [e])
        #expect(try store.trash().isEmpty)
    }

    @Test func editingATrashedEntryKeepsItInTrash() throws {
        let store = try EntryStore.inMemory()
        var e = entry()
        try store.save(e)
        try store.moveToTrash(e.id, now: t0)
        e.minutes = 30
        try store.save(e)
        #expect(try store.entries().isEmpty)
        #expect(try store.trash().count == 1)
    }

    @Test func trashIsPurgedOnlyAfter30Days() throws {
        let store = try EntryStore.inMemory()
        let recent = entry()
        let old = entry()
        try store.save(recent)
        try store.save(old)
        let day: TimeInterval = 24 * 60 * 60
        try store.moveToTrash(recent.id, now: t0.addingTimeInterval(-29 * day))
        try store.moveToTrash(old.id, now: t0.addingTimeInterval(-31 * day))

        #expect(try store.purgeExpiredTrash(now: t0).count == 1)
        #expect(try store.trash().map(\.entry.id) == [recent.id])
    }

    @Test func entriesWithoutMoneyRoundTrip() throws {
        let store = try EntryStore.inMemory()
        let e = entry(minutes: 540, cents: nil)
        try store.save(e)
        #expect(try store.entries().first?.expense == nil)
    }

    @Test func dataSurvivesReopeningTheFile() throws {
        let dir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let e = entry()
        do {
            let store = try EntryStore.onDisk(directory: dir)
            try store.save(e)
        }
        let reopened = try EntryStore.onDisk(directory: dir)
        #expect(try reopened.entries() == [e])
    }

    @Test func failedWriteLeavesNothingHalfSaved() throws {
        let store = try EntryStore.inMemory()
        let e = entry()
        struct Interrupted: Error {}
        #expect(throws: Interrupted.self) {
            try store.writer.write { db in
                try EntryRecord(e, updatedAt: t0).insert(db)
                throw Interrupted()
            }
        }
        #expect(try store.entries().isEmpty)
    }
}

struct AmountInputTests {
    @Test func parsesDollarsAndCents() {
        #expect(AmountInput.parse("42.80", decimalSeparator: ".") == .cents(4280))
        #expect(AmountInput.parse("$1,140", decimalSeparator: ".") == .cents(114_000))
        #expect(AmountInput.parse("18", decimalSeparator: ".") == .cents(1800))
        #expect(AmountInput.parse(".5", decimalSeparator: ".") == .cents(50))
        #expect(AmountInput.parse("", decimalSeparator: ".") == .empty)
    }

    @Test func rejectsWhatIsNotMoney() {
        #expect(AmountInput.parse("abc", decimalSeparator: ".") == .invalid)
        #expect(AmountInput.parse("4.555", decimalSeparator: ".") == .invalid)
        #expect(AmountInput.parse("1.2.3", decimalSeparator: ".") == .invalid)
    }

    @Test func flagsAMissingDecimalPoint() {
        #expect(AmountInput.parse("4280", decimalSeparator: ".") == .suspicious(typedCents: 428_000, suggestedCents: 4280))
        #expect(AmountInput.parse("999", decimalSeparator: ".") == .cents(99_900))
    }

    @Test func formatsForTheField() {
        #expect(AmountInput.text(cents: 4280, decimalSeparator: ".") == "42.80")
        #expect(AmountInput.text(cents: 1800, decimalSeparator: ".") == "18")
    }

    /// German, French, Russian and most other keypads type "," for the decimal mark.
    @Test func readsACommaKeypad() {
        #expect(AmountInput.parse("42,80", decimalSeparator: ",") == .cents(4280))
        #expect(AmountInput.parse("1.140,50", decimalSeparator: ",") == .cents(114_050))
        #expect(AmountInput.parse("1 140", decimalSeparator: ",") == .suspicious(typedCents: 114_000, suggestedCents: 1140))
        #expect(AmountInput.parse("42.80", decimalSeparator: ",") == .cents(4280))
        #expect(AmountInput.parse("18 €", decimalSeparator: ",") == .cents(1800))
        #expect(AmountInput.parse("4,555", decimalSeparator: ",") == .invalid)
        #expect(AmountInput.text(cents: 4280, decimalSeparator: ",") == "42,80")
    }
}

struct ChangesTests {
    @Test func describesAmountChange() {
        var old = SampleData.entries[1]
        old.expense?.amountCents = 1500
        let new = SampleData.entries[1]
        #expect(Changes.summary(from: old, to: new) == "Amount $15 → $18")
    }
}
