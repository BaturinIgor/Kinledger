import Foundation
import Observation

/// Holds what the screens show and routes every change through the store.
@MainActor
@Observable
final class AppModel {
    let store: EntryStore
    private(set) var entries: [Entry] = []
    private(set) var trash: [TrashedEntry] = []
    /// Shown to the person when the phone could not save. Never swallowed.
    var problem: String?

    init(store: EntryStore, problem: String? = nil) {
        self.store = store
        self.problem = problem
        reload()
    }

    static func live() -> AppModel {
        do {
            let store = try EntryStore.onDisk()
            try store.purgeExpiredTrash()
            return AppModel(store: store)
        } catch {
            // Keep the app usable, and say clearly that nothing is being kept.
            let fallback = try! EntryStore.inMemory()
            return AppModel(store: fallback, problem: "Kinledger could not open its storage on this iPhone, so new entries are not being kept. Restart the app. (\(error.localizedDescription))")
        }
    }

    static func preview(_ entries: [Entry] = SampleData.entries) -> AppModel {
        let store = try! EntryStore.inMemory()
        for entry in entries { try? store.save(entry) }
        return AppModel(store: store)
    }

    func reload() {
        do {
            entries = try store.entries()
            trash = try store.trash()
        } catch {
            problem = "Could not read your entries: \(error.localizedDescription)"
        }
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

    @discardableResult
    private func perform(_ work: () throws -> Void) -> Bool {
        defer { reload() }
        do {
            try work()
            return true
        } catch {
            problem = "Could not save: \(error.localizedDescription)"
            return false
        }
    }
}
