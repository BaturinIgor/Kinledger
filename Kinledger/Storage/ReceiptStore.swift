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

    /// Writes a photo under a known name, used when it comes back from the cloud.
    func write(_ jpeg: Data, name: String) throws {
        guard Self.isSafeName(name) else { throw CocoaError(.fileWriteInvalidFileName) }
        try jpeg.write(to: url(for: name), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    /// A plain file name such as "UUID.jpg", never a path that could leave the receipts folder.
    static func isSafeName(_ name: String) -> Bool {
        !name.isEmpty && !name.contains("/") && !name.contains("\\") && !name.hasPrefix(".")
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
