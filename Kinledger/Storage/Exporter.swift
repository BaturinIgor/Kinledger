import Foundation

/// Builds the files people take out of the app: all data, and the tax-year package.
/// Both are a ZIP with a CSV and the receipt photos, so nothing depends on Kinledger to open.
enum Exporter {
    /// "Export all my data": entries.csv and receipts/.
    static func allData(entries: [Entry], receipts: ReceiptStore, now: Date = .now) throws -> URL {
        let name = "Kinledger-export-\(CSV.date(now))"
        return try package(
            name: name,
            csvName: "entries.csv",
            csv: CSV.allEntries(entries),
            receiptNames: entries.compactMap { $0.expense?.receiptPath },
            receipts: receipts
        )
    }

    /// The US medical-expense export for one year (R14).
    static func taxYear(_ summary: TaxYearSummary, receipts: ReceiptStore) throws -> URL {
        try package(
            name: "Kinledger-medical-expenses-\(summary.year)",
            csvName: "medical-expenses-\(summary.year).csv",
            csv: CSV.taxYear(summary),
            receiptNames: summary.expenses.compactMap { $0.expense?.receiptPath },
            receipts: receipts
        )
    }

    private static func package(name: String, csvName: String, csv: String,
                                receiptNames: [String], receipts: ReceiptStore) throws -> URL {
        let fm = FileManager.default
        let work = fm.temporaryDirectory.appending(path: "export-\(UUID().uuidString)")
        let folder = work.appending(path: name)
        let receiptsFolder = folder.appending(path: "receipts")
        try fm.createDirectory(at: receiptsFolder, withIntermediateDirectories: true)
        try Data(csv.utf8).write(to: folder.appending(path: csvName))
        for receipt in receiptNames where receipts.exists(receipt) {
            try fm.copyItem(at: receipts.url(for: receipt), to: receiptsFolder.appending(path: receipt))
        }
        let zip = work.appending(path: "\(name).zip")
        try zipFolder(folder, to: zip)
        return zip
    }

    /// Uses the system's own ZIP support: coordinating a read "for uploading" yields a zipped copy.
    static func zipFolder(_ folder: URL, to destination: URL) throws {
        var coordinationError: NSError?
        var copyError: Error?
        NSFileCoordinator().coordinate(readingItemAt: folder, options: .forUploading, error: &coordinationError) { zipped in
            do {
                try? FileManager.default.removeItem(at: destination)
                try FileManager.default.copyItem(at: zipped, to: destination)
            } catch {
                copyError = error
            }
        }
        if let error = coordinationError ?? copyError { throw error }
    }
}
