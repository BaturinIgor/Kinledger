import Foundation
import Observation

/// Holds what the screens show and routes every change through the store.
@MainActor
@Observable
final class AppModel {
    let store: EntryStore
    let receipts: ReceiptStore
    let cloud: CloudBackup
    private(set) var entries: [Entry] = []
    private(set) var trash: [TrashedEntry] = []
    /// Nil until onboarding is done.
    private(set) var profile: CareProfile?
    private(set) var recipients: [Recipient] = []
    /// Shown to the person when the phone could not save. Never swallowed.
    var problem: String?

    init(store: EntryStore, receipts: ReceiptStore, problem: String? = nil, cloudConfig: CloudConfig? = nil) {
        self.store = store
        self.receipts = receipts
        self.problem = problem
        cloud = CloudBackup(store: store, receipts: receipts, config: cloudConfig)
        reload()
        cloud.onDownloaded = { [weak self] in self?.reload() }
    }

    static func live() -> AppModel {
        do {
            let store = try EntryStore.onDisk()
            let receipts = try ReceiptStore.onDisk()
            let purged = try store.purgeExpiredTrash()
            receipts.delete(purged.receiptFiles)
            return AppModel(store: store, receipts: receipts, cloudConfig: .current)
        } catch {
            // Keep the app usable, and say clearly that nothing is being kept.
            let fallback = try! EntryStore.inMemory()
            return AppModel(store: fallback, receipts: try! ReceiptStore.temporary(), problem: "Kinledger could not open its storage on this iPhone, so new entries are not being kept. Restart the app. (\(error.localizedDescription))")
        }
    }

    static func preview(_ entries: [Entry] = SampleData.entries, onboarded: Bool = true) -> AppModel {
        let store = try! EntryStore.inMemory()
        for entry in entries { try? store.save(entry) }
        if onboarded {
            try? store.saveProfile(CareProfile(parentName: "Margaret", nickname: "Mom", country: .us))
            try? store.saveRecipient(Recipient(id: UUID(), name: "Dave", contact: "dave@example.com", relation: "Brother"))
        }
        return AppModel(store: store, receipts: try! ReceiptStore.temporary())
    }

    func reload() {
        do {
            entries = try store.entries()
            trash = try store.trash()
            profile = try store.profile()
            recipients = try store.recipients()
        } catch {
            problem = "Could not read your entries: \(error.localizedDescription)"
        }
    }

    var careProfile: CareProfile { profile ?? .placeholder }

    func saveProfile(_ profile: CareProfile) {
        perform { try store.saveProfile(profile) }
    }

    func saveRecipient(_ recipient: Recipient) {
        perform { try store.saveRecipient(recipient) }
    }

    func deleteRecipient(_ id: UUID) {
        perform { try store.deleteRecipient(id) }
    }

    func entry(_ id: UUID) -> Entry? {
        entries.first { $0.id == id }
    }

    func history(of id: UUID) -> [EntryRevision] {
        (try? store.history(of: id)) ?? []
    }

    /// Returns false when the save failed; the problem is shown to the person.
    @discardableResult
    func save(_ entry: Entry) -> Bool {
        perform { try store.save(entry) }
    }

    func moveToTrash(_ id: UUID) {
        perform { try store.moveToTrash(id) }
    }

    func restoreFromTrash(_ id: UUID) {
        perform { try store.restoreFromTrash(id) }
    }

    func restore(_ revision: EntryRevision) {
        perform { try store.restore(revision) }
    }

    /// Saves a receipt photo and returns its file name, or nil if it could not be saved.
    func saveReceipt(_ jpeg: Data) -> String? {
        do {
            return try receipts.save(jpeg)
        } catch {
            problem = "Could not save the receipt photo: \(error.localizedDescription)"
            return nil
        }
    }

    func exportAllData() -> URL? {
        attempt("Could not build the export") { try Exporter.allData(entries: entries + trash.map(\.entry), receipts: receipts) }
    }

    func exportTaxYear(_ year: Int) -> URL? {
        attempt("Could not build the tax export") {
            try Exporter.taxYear(TaxYearSummary(entries: entries, year: year), receipts: receipts)
        }
    }

    private func attempt<T>(_ message: String, _ work: () throws -> T) -> T? {
        do {
            return try work()
        } catch {
            problem = "\(message): \(error.localizedDescription)"
            return nil
        }
    }

    @discardableResult
    private func perform(_ work: () throws -> Void) -> Bool {
        defer { reload() }
        do {
            try work()
            cloud.syncSoon()
            return true
        } catch {
            problem = "Could not save: \(error.localizedDescription)"
            return false
        }
    }
}
