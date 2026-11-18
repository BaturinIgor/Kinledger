import Foundation
import Testing
@testable import Kinledger

struct ReportTests {
    let utc = TimeZone(identifier: "UTC")!

    @Test func monthReportCountsOnlyWhatIPaid() {
        let report = MonthReport(entries: SampleData.entries, month: SampleData.month)
        #expect(report.entries.count == 4)
        #expect(report.totals.outOfPocketCents == 6080)
        // Groceries were paid by her, so they are not in "where my money went".
        #expect(report.spending.map(\.category) == [.pharmacy, .doctor])
        #expect(report.headline(parentName: "Mom") == "You spent 12.5 h with Mom, visited 3 times and paid $60.80 yourself.")
    }

    @Test func taxYearKeepsMedicalExpensesIPaid() {
        var entries = SampleData.entries
        entries[0].expense?.receiptPath = "a.jpg"
        let summary = TaxYearSummary(entries: entries, year: 2026)
        #expect(summary.expenses.map(\.title) == ["Dr. Patel, cardiology", "Pharmacy pickup"])
        #expect(summary.totalCents == 6080)
        #expect(summary.withReceipt == 1)
        #expect(summary.withoutReceipt == 1)
        #expect(TaxYearSummary(entries: entries, year: 2025).expenses.isEmpty)
    }

    @Test func csvEscapesCommasQuotesAndFormulas() {
        #expect(CSV.field("Dr. Patel, cardiology") == "\"Dr. Patel, cardiology\"")
        #expect(CSV.field("She said \"fine\"") == "\"She said \"\"fine\"\"\"")
        #expect(CSV.field("=SUM(A1)") == "'=SUM(A1)")
        #expect(CSV.field("Groceries") == "Groceries")
        #expect(CSV.amount(4280) == "42.80")
        #expect(CSV.amount(1800) == "18.00")
    }

    @Test func taxCSVHasOneRowPerExpense() {
        var entries = SampleData.entries
        entries[0].expense?.receiptPath = "a.jpg"
        let csv = CSV.taxYear(TaxYearSummary(entries: entries, year: 2026), timeZone: .current)
        let lines = csv.split(separator: "\r\n")
        #expect(lines.count == 3)
        #expect(lines[0] == "date,description,category,amount_usd,receipt_file")
        #expect(lines[1] == "2026-11-16,\"Dr. Patel, cardiology\",Doctor,18.00,no receipt")
        #expect(lines[2] == "2026-11-18,Pharmacy pickup,Pharmacy,42.80,receipts/a.jpg")
    }

    @Test func allDataCSVIncludesEveryEntryAndNote() {
        let csv = CSV.allEntries(SampleData.entries, timeZone: utc)
        #expect(csv.split(separator: "\r\n").count == 5)
        #expect(csv.contains("After a fall"))
    }

    @Test func exportZipContainsCSVAndReceipts() throws {
        let receipts = try ReceiptStore.temporary()
        let name = try receipts.save(Data([0xFF, 0xD8, 0xFF]))
        var entries = SampleData.entries
        entries[0].expense?.receiptPath = name

        let zip = try Exporter.allData(entries: entries, receipts: receipts, now: SampleData.month)
        #expect(zip.lastPathComponent == "Kinledger-export-2026-11-18.zip")
        let size = try FileManager.default.attributesOfItem(atPath: zip.path)[.size] as? Int ?? 0
        #expect(size > 100)
        // A ZIP file starts with "PK".
        let head = try Data(contentsOf: zip).prefix(2)
        #expect(head == Data([0x50, 0x4B]))
    }

    @Test func purgeReturnsReceiptFilesToDelete() throws {
        let store = try EntryStore.inMemory()
        var e = SampleData.entries[0]
        e.expense?.receiptPath = "r.jpg"
        try store.save(e)
        try store.moveToTrash(e.id, now: SampleData.month.addingTimeInterval(-40 * 24 * 3600))
        #expect(try store.purgeExpiredTrash(now: SampleData.month) == PurgeResult(count: 1, receiptFiles: ["r.jpg"]))
    }
}
