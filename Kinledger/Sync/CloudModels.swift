import Foundation

/// An entry as the cloud stores it: the entry itself plus when it last changed and whether it is in the trash.
struct CloudEntry: Codable, Sendable, Hashable {
    var entry: Entry
    var updatedAt: Date
    var deletedAt: Date?

    var id: UUID { entry.id }
}

/// One row read back from the cloud. `changedAt` is the server's own clock, used only as a cursor.
struct RemoteChange: Sendable, Hashable {
    var item: CloudEntry
    var changedAt: String
}

struct CloudProfile: Codable, Sendable, Hashable {
    var profile: CareProfile
    var updatedAt: Date
}

/// Dates in cloud payloads are ISO 8601 with milliseconds, the same precision SQLite keeps on the phone,
/// so an entry that goes up and comes back compares equal.
enum CloudCodec {
    static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(format(date))
        }
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let text = try container.decode(String.self)
            guard let date = parse(text) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Not an ISO 8601 date: \(text)")
            }
            return date
        }
        return decoder
    }

    /// "2026-11-18T15:00:00.123Z". Milliseconds are rounded here rather than left to the formatter,
    /// which truncates and can turn .123 into .122.
    static func format(_ date: Date) -> String {
        let totalMillis = Int64((date.timeIntervalSince1970 * 1000).rounded())
        let seconds = totalMillis >= 0 ? totalMillis / 1000 : (totalMillis - 999) / 1000
        let millis = totalMillis - seconds * 1000
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let base = formatter.string(from: Date(timeIntervalSince1970: TimeInterval(seconds)))
        return String(base.dropLast()) + String(format: ".%03lldZ", millis)
    }

    /// Reads our own format and the server's ("2026-11-18T15:00:00.123456+00:00"), to the millisecond.
    static func parse(_ text: String) -> Date? {
        guard let tIndex = text.firstIndex(of: "T") else { return nil }
        var head = text
        var fraction = 0.0
        if let dot = text[tIndex...].firstIndex(of: ".") {
            let digitsEnd = text[dot...].dropFirst().firstIndex { !$0.isNumber } ?? text.endIndex
            fraction = Double("0" + String(text[dot..<digitsEnd])) ?? 0
            head = String(text[..<dot]) + String(text[digitsEnd...])
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        guard let whole = formatter.date(from: head) else { return nil }
        let millis = Int64((whole.timeIntervalSince1970 * 1000).rounded()) + Int64((fraction * 1000).rounded())
        return Date(timeIntervalSince1970: TimeInterval(millis) / 1000)
    }
}
