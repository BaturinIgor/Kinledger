import Foundation
import Security

/// A private link to one month's report. Family open it in any browser; the token is the only key.
struct ReportLink: Sendable, Equatable {
    /// The page is static; the token goes after "#", so it never reaches a server log.
    static let page = URL(string: "https://baturinigor.github.io/Kinledger/r/")!

    let token: String
    let periodStart: Date
    let periodEnd: Date
    let includeNotes: Bool

    var url: URL {
        URL(string: Self.page.absoluteString + "#" + token)!
    }

    /// The calendar month that contains `month`, in the caregiver's own time zone.
    init(token: String = ReportLink.makeToken(), month: Date, includeNotes: Bool, calendar: Calendar = .current) {
        self.token = token
        let start = calendar.startOfMonth(for: month)
        periodStart = start
        periodEnd = calendar.date(byAdding: .month, value: 1, to: start) ?? start.addingTimeInterval(31 * 86_400)
        self.includeNotes = includeNotes
    }

    /// 32 random bytes as URL-safe base64: 43 characters, not guessable.
    static func makeToken() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        if status != errSecSuccess {
            var generator = SystemRandomNumberGenerator()
            bytes = bytes.map { _ in UInt8.random(in: 0...255, using: &generator) }
        }
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
