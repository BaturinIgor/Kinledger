import Foundation
import Testing
@testable import Kinledger

/// Cloud backup: what counts as pending, who wins a conflict, and a full round trip between two phones.
struct SyncTests {
    let t0 = SampleData.date(2026, 11, 18, 15, 0)

    func entry(cents: Int = 4280, receipt: String? = nil) -> Entry {
        Entry(
            id: UUID(),
            category: .pharmacy,
            title: "Pharmacy pickup",
            occurredAt: t0,
            loggedAt: t0,
            minutes: 25,
            visit: false,
            expense: Expense(amountCents: cents, payer: .me, medical: true, receiptPath: receipt),
            note: "Receipt saved"
        )
    }

    // MARK: Local bookkeeping

    @Test func newAndEditedEntriesArePending() throws {
        let store = try EntryStore.inMemory()
        var e = entry()
        try store.save(e, now: t0)
        let pending = try store.pendingEntries()
        #expect(pending.map(\.id) == [e.id])

        try store.markSynced(pending)
        #expect(try store.pendingEntries().isEmpty)

        e.title = "Pharmacy, two bags"
        try store.save(e, now: t0.addingTimeInterval(60))
        #expect(try store.pendingCount() == 1)
    }

    @Test func trashingIsPendingSoTheCloudLearnsIt() throws {
        let store = try EntryStore.inMemory()
        let e = entry()
        try store.save(e, now: t0)
        try store.markSynced(store.pendingEntries())
        try store.moveToTrash(e.id, now: t0.addingTimeInterval(60))
        let pending = try store.pendingEntries()
        #expect(pending.count == 1)
        #expect(pending[0].deletedAt != nil)
    }

    @Test func editDuringUploadStaysPending() throws {
        let store = try EntryStore.inMemory()
        var e = entry()
        try store.save(e, now: t0)
        let uploading = try store.pendingEntries()
        e.title = "Changed while uploading"
        try store.save(e, now: t0.addingTimeInterval(5))
        try store.markSynced(uploading)
        #expect(try store.pendingEntries().first?.entry.title == "Changed while uploading")
    }

    @Test func newerCloudVersionWinsAndLocalGoesToHistory() throws {
        let store = try EntryStore.inMemory()
        let e = entry(cents: 4280)
        try store.save(e, now: t0)
        var remote = e
        remote.expense?.amountCents = 5000
        let result = try store.applyRemote([CloudEntry(entry: remote, updatedAt: t0.addingTimeInterval(120))], now: t0.addingTimeInterval(130))

        #expect(result.applied == 1)
        #expect(try store.entries().first?.expense?.amountCents == 5000)
        #expect(try store.history(of: e.id).first?.previous.expense?.amountCents == 4280)
        #expect(try store.pendingEntries().isEmpty)
    }

    @Test func olderCloudVersionNeverOverwritesThePhone() throws {
        let store = try EntryStore.inMemory()
        let e = entry(cents: 4280)
        try store.save(e, now: t0.addingTimeInterval(300))
        var remote = e
        remote.expense?.amountCents = 1
        let result = try store.applyRemote([CloudEntry(entry: remote, updatedAt: t0)])
        #expect(result.keptLocal == 1)
        #expect(try store.entries().first?.expense?.amountCents == 4280)
    }

    @Test func oldTrashIsNotBroughtBack() throws {
        let store = try EntryStore.inMemory()
        let old = CloudEntry(entry: entry(), updatedAt: t0, deletedAt: t0)
        try store.applyRemote([old], now: t0.addingTimeInterval(40 * 24 * 60 * 60))
        #expect(try store.trash().isEmpty)
        #expect(try store.entries().isEmpty)
    }

    @Test func cloudPayloadRoundTripsExactly() throws {
        let store = try EntryStore.inMemory()
        try store.save(entry(), now: t0)
        let item = try #require(store.pendingEntries().first)
        let data = try CloudCodec.encoder().encode(item)
        let back = try CloudCodec.decoder().decode(CloudEntry.self, from: data)
        #expect(back == item)
    }

    @Test func datesKeepTheirMilliseconds() throws {
        let date = t0.addingTimeInterval(0.123)
        let text = CloudCodec.format(date)
        #expect(text.hasSuffix(".123Z"))
        let back = try #require(CloudCodec.parse(text))
        #expect(abs(back.timeIntervalSince(date)) < 0.0005)
        let fromServer = try #require(CloudCodec.parse("2026-11-18T15:00:00.123456+00:00"))
        #expect(CloudCodec.format(fromServer) == "2026-11-18T15:00:00.123Z")
        #expect(CloudCodec.parse("2026-11-18T15:00:00Z") != nil)
    }

    @Test func turningBackupOffMakesEverythingUploadAgainLater() throws {
        let store = try EntryStore.inMemory()
        try store.save(entry(receipt: "a.jpg"), now: t0)
        try store.markSynced(store.pendingEntries())
        try store.markReceiptUploaded("a.jpg")
        try store.setSyncValue("cursor", for: EntryStore.cursorKey)

        try store.resetSyncState()

        #expect(try store.pendingCount() == 1)
        #expect(try store.receiptsToUpload() == ["a.jpg"])
        #expect(try store.syncValue(EntryStore.cursorKey) == nil)
        #expect(try store.entries().count == 1)
    }

    @Test func deleteAccountSendsTheAppleCode() async throws {
        let transport = RecordingTransport(body: Data(#"{"deleted":true}"#.utf8))
        let client = CloudClient(config: config, transport: transport)
        try await client.deleteAccount(authorizationCode: "code-1", session: session)
        let request = try #require(transport.requests.first)
        #expect(request.url?.path == "/functions/v1/delete-account")
        let body = try #require(JSONSerialization.jsonObject(with: request.httpBody ?? Data()) as? [String: String])
        #expect(body["authorization_code"] == "code-1")
    }

    @Test func reportLinkTokensAreLongAndUrlSafe() {
        let a = ReportLink.makeToken()
        let b = ReportLink.makeToken()
        #expect(a.count == 43)
        #expect(a != b)
        #expect(a.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" })
    }

    @Test func reportLinkCoversTheWholeMonthInLocalTime() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        let mid = calendar.date(from: DateComponents(year: 2026, month: 11, day: 18, hour: 12))!
        let link = ReportLink(token: "t", month: mid, includeNotes: false, calendar: calendar)
        #expect(link.periodStart == calendar.date(from: DateComponents(year: 2026, month: 11, day: 1)))
        #expect(link.periodEnd == calendar.date(from: DateComponents(year: 2026, month: 12, day: 1)))
        #expect(link.url.absoluteString == "https://baturinigor.github.io/Kinledger/r/#t")
    }

    @Test func reportLinkRequests() async throws {
        let transport = RecordingTransport()
        let client = CloudClient(config: config, transport: transport)
        let link = ReportLink(token: "tok", month: t0, includeNotes: true)
        try await client.createReportLink(link, session: session)
        try await client.revokeAllReportLinks(session: session)

        let create = transport.requests[0]
        #expect(create.httpMethod == "POST")
        #expect(create.url?.path == "/rest/v1/report_links")
        let rows = try #require(JSONSerialization.jsonObject(with: create.httpBody ?? Data()) as? [[String: Any]])
        #expect(rows.first?["token"] as? String == "tok")
        #expect(rows.first?["include_notes"] as? Bool == true)

        let revoke = transport.requests[1]
        #expect(revoke.httpMethod == "PATCH")
        #expect(revoke.url?.query == "revoked_at=is.null")
    }

    @Test func receiptNamesCannotLeaveTheFolder() {
        #expect(ReceiptStore.isSafeName("3F2A.jpg"))
        #expect(!ReceiptStore.isSafeName("../kinledger.sqlite"))
        #expect(!ReceiptStore.isSafeName("a/b.jpg"))
        #expect(!ReceiptStore.isSafeName(""))
    }

    @Test func statusTextStaysCalm() {
        #expect(BackupStatus.waiting(3).text() == "3 changes saved on this iPhone, waiting to back up")
        #expect(BackupStatus.waiting(1).text() == "1 change saved on this iPhone, waiting to back up")
        #expect(BackupStatus.upToDate(.now).text() == "Backed up just now")
    }

    // MARK: Requests

    let config = CloudConfig(url: URL(string: "https://example.supabase.co")!, anonKey: "anon")
    let session = CloudSession(accessToken: "token", refreshToken: "refresh", expiresAt: .distantFuture, userID: "user-1")

    @Test func upsertSendsIdempotentRows() async throws {
        let transport = RecordingTransport()
        let client = CloudClient(config: config, transport: transport)
        let item = CloudEntry(entry: entry(), updatedAt: t0)
        try await client.upsert([item], session: session)

        let request = try #require(transport.requests.first)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.path == "/rest/v1/entries")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer token")
        #expect(request.value(forHTTPHeaderField: "apikey") == "anon")
        #expect(request.value(forHTTPHeaderField: "Prefer")?.contains("merge-duplicates") == true)
        let rows = try #require(JSONSerialization.jsonObject(with: request.httpBody ?? Data()) as? [[String: Any]])
        #expect(rows.first?["id"] as? String == item.id.uuidString.lowercased())
    }

    @Test func cursorKeepsItsPlusSign() async throws {
        let transport = RecordingTransport(body: Data("[]".utf8))
        let client = CloudClient(config: config, transport: transport)
        _ = try await client.changes(after: "2026-11-18T15:00:00.123456+00:00", session: session)
        let query = try #require(transport.requests.first?.url?.query)
        #expect(query.contains("%2B00:00"))
        #expect(!query.contains("+"))
    }

    @Test func signInReadsTheSession() async throws {
        let body = #"{"access_token":"a","refresh_token":"r","expires_in":3600,"user":{"id":"u"}}"#
        let transport = RecordingTransport(body: Data(body.utf8))
        let client = CloudClient(config: config, transport: transport)
        let s = try await client.signInWithApple(idToken: "apple", nonce: "n", now: t0)
        #expect(s == CloudSession(accessToken: "a", refreshToken: "r", expiresAt: t0.addingTimeInterval(3600), userID: "u"))
        #expect(transport.requests.first?.url?.query == "grant_type=id_token")
    }

    @Test func expiredSessionAsksToSignIn() {
        #expect(CloudError.http(status: 401, message: "").needsSignIn)
        #expect(!CloudError.http(status: 500, message: "").needsSignIn)
    }

    // MARK: Two phones

    @Test func newPhoneGetsEverythingBack() async throws {
        let cloud = FakeCloud()
        let client = CloudClient(config: config, transport: cloud)

        // Phone A: one entry with a receipt photo, one in the trash, and the profile.
        let phoneA = try EntryStore.inMemory()
        let receiptsA = try ReceiptStore.temporary()
        let photo = Data([0xFF, 0xD8, 0xFF, 0x01])
        let name = try receiptsA.save(photo)
        let kept = entry(receipt: name)
        let trashed = entry(cents: 999)
        try phoneA.save(kept, now: t0)
        try phoneA.save(trashed, now: t0)
        try phoneA.moveToTrash(trashed.id, now: t0.addingTimeInterval(10))
        try phoneA.saveProfile(CareProfile(parentName: "Margaret", nickname: "Mom", country: .us), now: t0)

        let up = try await SyncEngine(store: phoneA, receipts: receiptsA, client: client).run(session: session, now: t0)
        #expect(up.uploaded == 2)
        #expect(up.receiptsUploaded == 1)
        #expect(try phoneA.pendingEntries().isEmpty)

        // Phone B: empty, same account.
        let phoneB = try EntryStore.inMemory()
        let receiptsB = try ReceiptStore.temporary()
        let down = try await SyncEngine(store: phoneB, receipts: receiptsB, client: client).run(session: session, now: t0.addingTimeInterval(60))

        #expect(down.downloaded == 2)
        #expect(try phoneB.entries() == [kept])
        #expect(try phoneB.trash().map(\.entry) == [trashed])
        #expect(try phoneB.profile()?.nickname == "Mom")
        #expect(try Data(contentsOf: receiptsB.url(for: name)) == photo)
        #expect(try phoneB.pendingEntries().isEmpty)

        // A second pass moves nothing.
        let again = try await SyncEngine(store: phoneB, receipts: receiptsB, client: client).run(session: session, now: t0.addingTimeInterval(120))
        #expect(again == SyncSummary())
    }

    @Test func editsOnTwoPhonesMeetWithoutLoss() async throws {
        let cloud = FakeCloud()
        let client = CloudClient(config: config, transport: cloud)
        let phoneA = try EntryStore.inMemory()
        let phoneB = try EntryStore.inMemory()
        let receipts = try ReceiptStore.temporary()
        let original = entry(cents: 4280)

        try phoneA.save(original, now: t0)
        _ = try await SyncEngine(store: phoneA, receipts: receipts, client: client).run(session: session, now: t0)
        _ = try await SyncEngine(store: phoneB, receipts: receipts, client: client).run(session: session, now: t0)

        var onA = original
        onA.expense?.amountCents = 4500
        try phoneA.save(onA, now: t0.addingTimeInterval(100))
        var onB = original
        onB.expense?.amountCents = 4999
        try phoneB.save(onB, now: t0.addingTimeInterval(200))

        _ = try await SyncEngine(store: phoneA, receipts: receipts, client: client).run(session: session, now: t0.addingTimeInterval(300))
        _ = try await SyncEngine(store: phoneB, receipts: receipts, client: client).run(session: session, now: t0.addingTimeInterval(310))
        _ = try await SyncEngine(store: phoneA, receipts: receipts, client: client).run(session: session, now: t0.addingTimeInterval(320))

        // The later edit wins on both phones, and phone A keeps its own edit in history.
        #expect(try phoneA.entries().first?.expense?.amountCents == 4999)
        #expect(try phoneB.entries().first?.expense?.amountCents == 4999)
        #expect(try phoneA.history(of: original.id).contains { $0.previous.expense?.amountCents == 4500 })
    }
}

// MARK: Fakes

/// Answers every request with the same body and records what was sent.
final class RecordingTransport: HTTPTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var sent: [URLRequest] = []
    let body: Data

    init(body: Data = Data()) {
        self.body = body
    }

    var requests: [URLRequest] { lock.withLock { sent } }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        lock.withLock { sent.append(request) }
        return (body, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
    }
}

/// A tiny in-memory stand-in for the Supabase endpoints the app uses, with the same rules as the
/// SQL trigger: rows are keyed by id, an older update never replaces a newer one, and every write
/// gets a later `changed_at`.
final class FakeCloud: HTTPTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var rows: [String: (payload: Any, updatedAt: String, changedAt: String)] = [:]
    private var profile: Any?
    private var files: [String: Data] = [:]
    private var clock = 0

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (status, data) = lock.withLock { handle(request) }
        return (data, HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
    }

    private func handle(_ request: URLRequest) -> (Int, Data) {
        let url = request.url!
        let path = url.path
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let method = request.httpMethod ?? "GET"

        switch (method, path) {
        case ("POST", "/rest/v1/entries"):
            let body = (try? JSONSerialization.jsonObject(with: request.httpBody ?? Data())) as? [[String: Any]] ?? []
            for row in body {
                guard let id = row["id"] as? String, let updatedAt = row["updated_at"] as? String, let payload = row["payload"] else { continue }
                if let existing = rows[id], let old = CloudCodec.parse(existing.updatedAt), let new = CloudCodec.parse(updatedAt), new < old {
                    continue
                }
                clock += 1
                rows[id] = (payload, updatedAt, String(format: "%012d", clock))
            }
            return (201, Data())

        case ("GET", "/rest/v1/entries"):
            let after = query.first { $0.name == "changed_at" }?.value.map { String($0.dropFirst(3)) }
            let limit = Int(query.first { $0.name == "limit" }?.value ?? "") ?? 500
            let page = rows.values
                .filter { after == nil || $0.changedAt > after! }
                .sorted { $0.changedAt < $1.changedAt }
                .prefix(limit)
                .map { ["payload": $0.payload, "changed_at": $0.changedAt] as [String: Any] }
            return (200, (try? JSONSerialization.data(withJSONObject: Array(page))) ?? Data("[]".utf8))

        case ("POST", "/rest/v1/profiles"):
            let body = (try? JSONSerialization.jsonObject(with: request.httpBody ?? Data())) as? [[String: Any]] ?? []
            profile = body.first?["payload"]
            return (201, Data())

        case ("GET", "/rest/v1/profiles"):
            let list: [[String: Any]] = profile.map { [["payload": $0]] } ?? []
            return (200, (try? JSONSerialization.data(withJSONObject: list)) ?? Data("[]".utf8))

        case ("POST", _) where path.hasPrefix("/storage/v1/object/receipts/"):
            files[path] = request.httpBody ?? Data()
            return (200, Data("{}".utf8))

        case ("GET", _) where path.hasPrefix("/storage/v1/object/receipts/"):
            if let data = files[path] { return (200, data) }
            return (404, Data())

        default:
            return (404, Data())
        }
    }
}
