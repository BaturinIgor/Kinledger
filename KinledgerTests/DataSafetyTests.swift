import Foundation
import Testing
@testable import Kinledger

/// The release-blocking scenarios from docs/data-safety.md that the other suites do not already cover.
/// The full map of scenario → test is in docs/data-safety.md.
struct DataSafetyTests {
    let t0 = SampleData.date(2026, 11, 18, 15, 0)
    let config = CloudConfig(url: URL(string: "https://example.supabase.co")!, anonKey: "anon")
    let session = CloudSession(accessToken: "token", refreshToken: "refresh", expiresAt: .distantFuture, userID: "user-1")

    func entry(_ n: Int, receipt: String? = nil) -> Entry {
        Entry(
            id: UUID(),
            category: .pharmacy,
            title: "Entry \(n)",
            occurredAt: t0.addingTimeInterval(Double(n) * 60),
            loggedAt: t0.addingTimeInterval(Double(n) * 60),
            minutes: 15 + n,
            visit: n % 3 == 0,
            expense: Expense(amountCents: 100 * n + 7, payer: .me, medical: true, receiptPath: receipt),
            note: n % 2 == 0 ? "Note \(n)" : nil
        )
    }

    // 1. Offline: airplane mode, 20 entries and 5 receipts, network back on, everything reaches the cloud.
    @Test func offlineEntriesAndReceiptsAllReachTheCloudLater() async throws {
        let phone = try EntryStore.inMemory()
        let receipts = try ReceiptStore.temporary()
        var saved: [Entry] = []
        for n in 1...20 {
            let receipt = n <= 5 ? try receipts.save(Data([0xFF, 0xD8, UInt8(n)])) : nil
            let e = entry(n, receipt: receipt)
            try phone.save(e, now: t0)
            saved.append(e)
        }

        let offline = CloudClient(config: config, transport: OfflineTransport())
        await #expect(throws: (any Error).self) {
            _ = try await SyncEngine(store: phone, receipts: receipts, client: offline).run(session: session, now: t0)
        }
        #expect(try phone.pendingEntries().count == 20)
        #expect(try phone.entries().count == 20)

        let cloud = FakeCloud()
        let online = CloudClient(config: config, transport: cloud)
        let up = try await SyncEngine(store: phone, receipts: receipts, client: online).run(session: session, now: t0.addingTimeInterval(600))
        #expect(up.uploaded == 20)
        #expect(up.receiptsUploaded == 5)
        #expect(try phone.pendingEntries().isEmpty)

        // A second phone on the same account sees all of it.
        let other = try EntryStore.inMemory()
        let otherReceipts = try ReceiptStore.temporary()
        let down = try await SyncEngine(store: other, receipts: otherReceipts, client: online).run(session: session, now: t0.addingTimeInterval(700))
        #expect(down.downloaded == 20)
        #expect(down.receiptsDownloaded == 5)
        #expect(Set(try other.entries()) == Set(saved))
    }

    // 2. App killed mid-save: an upload that is sent again after a restart creates no duplicate.
    @Test func uploadRepeatedAfterACrashMakesNoDuplicate() async throws {
        let cloud = FakeCloud()
        let client = CloudClient(config: config, transport: cloud)
        let phone = try EntryStore.inMemory()
        let receipts = try ReceiptStore.temporary()
        let e = entry(1)
        try phone.save(e, now: t0)
        _ = try await SyncEngine(store: phone, receipts: receipts, client: client).run(session: session, now: t0)

        // The app died before it marked the entry as synced: a fresh store with the same row uploads it again.
        let restarted = try EntryStore.inMemory()
        try restarted.save(e, now: t0)
        _ = try await SyncEngine(store: restarted, receipts: receipts, client: client).run(session: session, now: t0.addingTimeInterval(60))

        let other = try EntryStore.inMemory()
        _ = try await SyncEngine(store: other, receipts: receipts, client: client).run(session: session, now: t0.addingTimeInterval(120))
        #expect(try other.entries() == [e])
    }

    // 7. A 5,000-entry database is reopened through the migrations with nothing lost.
    @Test func fiveThousandEntriesSurviveReopening() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "safety-\(UUID().uuidString)")
        var saved: [Entry] = []
        do {
            let store = try EntryStore.onDisk(directory: folder)
            for n in 0..<5_000 {
                let e = entry(n)
                try store.save(e, now: t0)
                saved.append(e)
            }
        }
        let reopened = try EntryStore.onDisk(directory: folder)
        let entries = try reopened.entries()
        #expect(entries.count == 5_000)
        #expect(Set(entries) == Set(saved))
    }

    // 8. Bad network: a receipt upload fails three times, then arrives; the photo never leaves the phone.
    @Test func receiptUploadThatFailsThreeTimesArrivesOnTheFourth() async throws {
        let cloud = FakeCloud()
        let flaky = FlakyReceipts(cloud: cloud, failures: 3)
        let client = CloudClient(config: config, transport: flaky)
        let phone = try EntryStore.inMemory()
        let receipts = try ReceiptStore.temporary()
        let photo = Data([0xFF, 0xD8, 0xFF, 0x42])
        let name = try receipts.save(photo)
        try phone.save(entry(1, receipt: name), now: t0)

        for attempt in 1...3 {
            await #expect(throws: (any Error).self) {
                _ = try await SyncEngine(store: phone, receipts: receipts, client: client)
                    .run(session: session, now: t0.addingTimeInterval(Double(attempt)))
            }
            #expect(try phone.receiptsToUpload().contains(name))
            #expect(try Data(contentsOf: receipts.url(for: name)) == photo)
        }

        let summary = try await SyncEngine(store: phone, receipts: receipts, client: client).run(session: session, now: t0.addingTimeInterval(4))
        #expect(summary.receiptsUploaded == 1)
        #expect(try phone.receiptsToUpload().isEmpty)
        #expect(try Data(contentsOf: receipts.url(for: name)) == photo)

        let other = try EntryStore.inMemory()
        let otherReceipts = try ReceiptStore.temporary()
        _ = try await SyncEngine(store: other, receipts: otherReceipts, client: client).run(session: session, now: t0.addingTimeInterval(5))
        #expect(try Data(contentsOf: otherReceipts.url(for: name)) == photo)
    }

    // 10. Leaving Pro: export of every entry, including the trash, needs no subscription.
    @MainActor @Test func exportWorksWithoutPro() throws {
        let model = AppModel.preview()
        let all = model.entries
        model.moveToTrash(all[0].id)
        #expect(model.trash.count == 1)
        // AppModel has no subscription state at all: the export cannot be locked behind Pro.
        let zip = try #require(model.exportAllData())
        #expect(try Data(contentsOf: zip).prefix(2) == Data([0x50, 0x4B]))
        let csv = CSV.allEntries(model.entries + model.trash.map(\.entry))
        #expect(csv.split(separator: "\r\n").count == all.count + 1)
    }
}

/// No network at all, as in airplane mode.
struct OfflineTransport: HTTPTransport {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        throw URLError(.notConnectedToInternet)
    }
}

/// The cloud, except that the first `failures` receipt uploads come back as server errors.
final class FlakyReceipts: HTTPTransport, @unchecked Sendable {
    private let cloud: FakeCloud
    private let lock = NSLock()
    private var remaining: Int

    init(cloud: FakeCloud, failures: Int) {
        self.cloud = cloud
        self.remaining = failures
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let isReceiptUpload = request.httpMethod == "POST" && request.url!.path.hasPrefix("/storage/v1/object/receipts/")
        let fail = isReceiptUpload && lock.withLock {
            guard remaining > 0 else { return false }
            remaining -= 1
            return true
        }
        if fail {
            return (Data(), HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!)
        }
        return try await cloud.send(request)
    }
}
