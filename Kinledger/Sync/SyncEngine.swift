import Foundation

struct SyncSummary: Equatable, Sendable {
    var uploaded = 0
    var downloaded = 0
    var receiptsUploaded = 0
    var receiptsDownloaded = 0
}

/// One sync pass: receipts up, entries up, entries down, missing receipts down.
///
/// Order matters for safety: a receipt photo is in the cloud before the entry that points to it,
/// and nothing local is marked synced until the cloud has confirmed the write.
struct SyncEngine: Sendable {
    let store: EntryStore
    let receipts: ReceiptStore
    let client: CloudClient
    var batchSize = 200

    func run(session: CloudSession, now: Date = .now) async throws -> SyncSummary {
        var summary = SyncSummary()

        for name in try store.receiptsToUpload() {
            // A photo missing on this phone came from another device; nothing to upload.
            guard receipts.exists(name) else { continue }
            let data = try Data(contentsOf: receipts.url(for: name))
            try await client.uploadReceipt(name, data: data, session: session)
            try store.markReceiptUploaded(name, now: now)
            summary.receiptsUploaded += 1
        }

        while true {
            let batch = try store.pendingEntries(limit: batchSize)
            guard !batch.isEmpty else { break }
            try await client.upsert(batch, session: session)
            try store.markSynced(batch)
            summary.uploaded += batch.count
            if batch.count < batchSize { break }
        }

        if let profile = try store.pendingProfile() {
            try await client.upsertProfile(profile, session: session)
            try store.markProfileSynced(profile)
        } else if try store.profile() == nil, let remote = try await client.fetchProfile(session: session) {
            try store.applyRemoteProfile(remote)
        }

        var cursor = try store.syncValue(EntryStore.cursorKey)
        let pageSize = 500
        while true {
            let page = try await client.changes(after: cursor, limit: pageSize, session: session)
            guard let last = page.last else { break }
            let result = try store.applyRemote(page.map(\.item), now: now)
            summary.downloaded += result.applied
            cursor = last.changedAt
            try store.setSyncValue(cursor, for: EntryStore.cursorKey)
            if page.count < pageSize { break }
        }

        for name in try store.referencedReceipts() where ReceiptStore.isSafeName(name) && !receipts.exists(name) {
            guard let data = try? await client.downloadReceipt(name, session: session) else { continue }
            try receipts.write(data, name: name)
            try store.markReceiptUploaded(name, now: now)
            summary.receiptsDownloaded += 1
        }

        return summary
    }
}
