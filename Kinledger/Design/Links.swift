import Foundation

/// Public pages the App Store and the paywall link to. Served by GitHub Pages from docs/.
enum Links {
    static let privacy = URL(string: "https://baturinigor.github.io/Kinledger/privacy")!
    static let support = URL(string: "https://baturinigor.github.io/Kinledger/support")!
    /// Apple's standard licence agreement, used as the Terms of Use for subscriptions.
    static let terms = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
}
