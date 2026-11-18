import Foundation
import Testing
@testable import Kinledger

/// The app ships in 18 languages and follows the iPhone's language.
struct LocalizationTests {
    static let languages = ["en", "es", "fr", "de", "it", "pt-BR", "nl", "sv", "da", "nb",
                            "pl", "ru", "uk", "tr", "ja", "ko", "zh-Hans", "zh-Hant"]

    private func bundle(_ language: String) throws -> Bundle {
        let app = Bundle(for: AppModel.self)
        let path = try #require(app.path(forResource: language, ofType: "lproj"), "no \(language).lproj in the app")
        return try #require(Bundle(path: path))
    }

    private func text(_ key: String, _ language: String) throws -> String {
        try bundle(language).localizedString(forKey: key, value: "MISSING", table: nil)
    }

    @Test func everyLanguageIsInTheApp() {
        let shipped = Set(Bundle(for: AppModel.self).localizations)
        for language in Self.languages {
            #expect(shipped.contains(language), "\(language) is not shipped")
        }
    }

    @Test(arguments: LocalizationTests.languages.filter { $0 != "en" })
    func tabsAreTranslated(language: String) throws {
        let today = try text("Today", language)
        #expect(today != "MISSING")
        #expect(today != "Today")
    }

    @Test func russianPluralsFollowTheNumber() throws {
        let format = try text("%lld times", "ru")
        let ru = Locale(identifier: "ru")
        #expect(String(format: format, locale: ru, 1) == "1 раз")
        #expect(String(format: format, locale: ru, 3) == "3 раза")
        #expect(String(format: format, locale: ru, 5) == "5 раз")
    }

    @Test func twoNumbersKeepTheirPlaces() throws {
        let format = try text("Paid by you and marked medical. %lld expenses, %lld with receipts.", "pl")
        let text = String(format: format, locale: Locale(identifier: "pl"), 5, 2)
        #expect(text == "Zapłacone przez ciebie i oznaczone jako medyczne. 5 wydatków, 2 z paragonem.")
    }

    @Test func wordOrderCanChange() throws {
        let format = try text("%@'s care in %@", "ko")
        #expect(String(format: format, "엄마", "11월") == "11월 엄마 돌봄")
    }

    @Test func englishSaysOneEntry() throws {
        let format = try text("All %lld entries", "en")
        #expect(String(format: format, locale: Locale(identifier: "en"), 1) == "1 entry")
        #expect(String(format: format, locale: Locale(identifier: "en"), 4) == "All 4 entries")
    }
}
