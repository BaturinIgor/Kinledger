import Foundation
import Testing
@testable import Kinledger

/// Crash reports stay on the phone and leave only in the file the person shares.
struct DiagnosticsTests {
    let facts = AppFacts(version: "1.0.0", build: "7", system: "18.2", device: "iPhone16,2")

    func makeStore() -> Diagnostics {
        Diagnostics(folder: FileManager.default.temporaryDirectory
            .appending(path: "diagnostics-\(UUID().uuidString)", directoryHint: .isDirectory))
    }

    @Test func reportWithoutCrashesSaysSo() throws {
        let store = makeStore()
        let url = try #require(store.makeReport(app: facts))
        let text = try String(contentsOf: url, encoding: .utf8)
        #expect(text.contains("App: 1.0.0 (7)"))
        #expect(text.contains("Device: iPhone16,2"))
        #expect(text.contains("No crash or hang reports"))
    }

    @Test func savedReportsAreInTheFileOldestFirst() throws {
        let store = makeStore()
        store.save(Data(#"{"crash":"second"}"#.utf8), receivedAt: Date(timeIntervalSince1970: 2_000))
        store.save(Data(#"{"crash":"first"}"#.utf8), receivedAt: Date(timeIntervalSince1970: 1_000))
        let text = try String(contentsOf: try #require(store.makeReport(app: facts)), encoding: .utf8)
        let first = try #require(text.range(of: "first"))
        let second = try #require(text.range(of: "second"))
        #expect(first.lowerBound < second.lowerBound)
        #expect(!text.contains("No crash or hang reports"))
    }

    @Test func keepsOnlyTheNewestReports() {
        let store = makeStore()
        for i in 0..<(Diagnostics.keep + 5) {
            store.save(Data("{\"n\":\(i)}".utf8), receivedAt: Date(timeIntervalSince1970: Double(1_000 + i)))
        }
        let reports = store.storedReports()
        #expect(reports.count == Diagnostics.keep)
        let oldest = try? String(contentsOf: reports[0], encoding: .utf8)
        #expect(oldest == "{\"n\":5}")
    }
}
