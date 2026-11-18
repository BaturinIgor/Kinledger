import Foundation

/// Receipt photos as files next to the database. Entries refer to them by file name.
final class ReceiptStore: Sendable {
    let directory: URL

    init(directory: URL) throws {
        self.directory = directory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    static func onDisk() throws -> ReceiptStore {
        try ReceiptStore(directory: URL.applicationSupportDirectory.appending(path: "Receipts"))
    }

    static func temporary() throws -> ReceiptStore {
        try ReceiptStore(directory: FileManager.default.temporaryDirectory.appending(path: "Receipts-\(UUID().uuidString)"))
    }

    /// Writes the photo atomically and returns its file name.
    func save(_ jpeg: Data) throws -> String {
        let name = "\(UUID().uuidString).jpg"
        try jpeg.write(to: url(for: name), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        return name
    }

    func url(for name: String) -> URL {
        directory.appending(path: name)
    }

    func exists(_ name: String) -> Bool {
        FileManager.default.fileExists(atPath: url(for: name).path)
    }

    func delete(_ names: [String]) {
        for name in names {
            try? FileManager.default.removeItem(at: url(for: name))
        }
    }
}
