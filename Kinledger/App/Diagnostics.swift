import Foundation
import MetricKit
import UIKit

/// Crash and hang reports from MetricKit, kept only on this iPhone.
///
/// Nothing is uploaded: the person sends the file themselves from Me → Send diagnostics.
/// The reports hold call stacks and device facts, never entries, amounts or names.
final class Diagnostics: NSObject, MXMetricManagerSubscriber, @unchecked Sendable {
    static let shared = Diagnostics(folder: Diagnostics.defaultFolder)

    /// Older reports are dropped so the folder never grows without limit.
    static let keep = 20

    let folder: URL
    private let lock = NSLock()

    init(folder: URL) {
        self.folder = folder
    }

    private static var defaultFolder: URL {
        URL.applicationSupportDirectory.appending(path: "Diagnostics", directoryHint: .isDirectory)
    }

    /// Call once at launch.
    func start() {
        MXMetricManager.shared.add(self)
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            save(payload.jsonRepresentation(), receivedAt: payload.timeStampEnd)
        }
    }

    /// Stores one report and drops the oldest beyond `keep`.
    func save(_ json: Data, receivedAt date: Date) {
        lock.lock(); defer { lock.unlock() }
        let fm = FileManager.default
        try? fm.createDirectory(at: folder, withIntermediateDirectories: true)
        // Zero-padded seconds first, so names sort oldest first.
        let stamp = String(format: "%012d", Int(date.timeIntervalSince1970))
        let name = "diagnostic-\(stamp)-\(UUID().uuidString.prefix(8)).json"
        try? json.write(to: folder.appending(path: name), options: .atomic)

        let reports = storedReports()
        if reports.count > Self.keep {
            for old in reports.prefix(reports.count - Self.keep) { try? fm.removeItem(at: old) }
        }
    }

    /// Saved reports, oldest first.
    func storedReports() -> [URL] {
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        return files
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    /// One plain-text file to share: app and device facts, then every saved report.
    func makeReport(app: AppFacts, now: Date = .now) -> URL? {
        lock.lock(); defer { lock.unlock() }
        var text = """
        Kinledger diagnostics
        App: \(app.version) (\(app.build))
        iOS: \(app.system)
        Device: \(app.device)
        Created: \(now.ISO8601Format())

        """
        let reports = storedReports()
        if reports.isEmpty {
            text += "\nNo crash or hang reports on this iPhone.\n"
        }
        for url in reports {
            let body = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            text += "\n--- \(url.lastPathComponent)\n\(body)\n"
        }
        let out = FileManager.default.temporaryDirectory.appending(path: "Kinledger-diagnostics.txt")
        do {
            try text.write(to: out, atomically: true, encoding: .utf8)
            return out
        } catch {
            return nil
        }
    }
}

/// What the diagnostics file says about the app and phone.
struct AppFacts: Sendable {
    var version: String
    var build: String
    var system: String
    var device: String

    @MainActor static var current: AppFacts {
        let info = Bundle.main.infoDictionary ?? [:]
        return AppFacts(
            version: info["CFBundleShortVersionString"] as? String ?? "?",
            build: info["CFBundleVersion"] as? String ?? "?",
            system: UIDevice.current.systemVersion,
            device: Self.modelIdentifier()
        )
    }

    /// "iPhone16,2" rather than the marketing name: no lookup table to keep current.
    private static func modelIdentifier() -> String {
        var info = utsname()
        uname(&info)
        return withUnsafeBytes(of: &info.machine) { raw in
            String(decoding: raw.prefix(while: { $0 != 0 }), as: UTF8.self)
        }
    }
}
