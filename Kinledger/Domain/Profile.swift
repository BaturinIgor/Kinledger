import Foundation

/// Countries the first version is written for. Drives currency and which tax help is offered.
enum Country: String, Codable, Sendable, CaseIterable {
    case us = "US"
    case uk = "UK"
    case canada = "CA"
    case australia = "AU"
    case europe = "EU"

    var label: String {
        switch self {
        case .us: "United States"
        case .uk: "United Kingdom"
        case .canada: "Canada"
        case .australia: "Australia"
        case .europe: "Europe (euro)"
        }
    }

    var currencyCode: String {
        switch self {
        case .us: "USD"
        case .uk: "GBP"
        case .canada: "CAD"
        case .australia: "AUD"
        case .europe: "EUR"
        }
    }

    var locale: Locale {
        switch self {
        case .us: Locale(identifier: "en_US")
        case .uk: Locale(identifier: "en_GB")
        case .canada: Locale(identifier: "en_CA")
        case .australia: Locale(identifier: "en_AU")
        case .europe: Locale(identifier: "en_IE")
        }
    }

    /// The US medical-expense export (R14) only makes sense for US filers.
    var hasTaxExport: Bool { self == .us }
}

/// Who the caregiver looks after. One per account in version 1.0.
struct CareProfile: Codable, Hashable, Sendable {
    /// Their name, as on documents: "Margaret".
    var parentName: String
    /// What the caregiver calls them: "Mom". Used across the app and the report.
    var nickname: String
    var country: Country

    func money(_ cents: Int) -> String {
        Format.money(cents: cents, currency: country.currencyCode, locale: country.locale)
    }
}

/// A family member who gets the monthly report. They never need the app (R6).
struct Recipient: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var name: String
    /// Phone or email, as typed.
    var contact: String
    var relation: String
}

extension CareProfile {
    /// Used until onboarding is done, and in previews.
    static let placeholder = CareProfile(parentName: "", nickname: "Mom", country: .us)
}
