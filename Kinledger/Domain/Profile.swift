import Foundation

/// Countries the first version is written for. Drives currency and which tax help is offered.
enum Country: String, Codable, Sendable, CaseIterable {
    case us = "US"
    case uk = "UK"
    case canada = "CA"
    case australia = "AU"
    case europe = "EU"
    /// Anywhere else: money in the phone's own currency, no tax export.
    case other = "OTHER"

    var label: String {
        switch self {
        case .us: String(localized: "United States")
        case .uk: String(localized: "United Kingdom")
        case .canada: String(localized: "Canada")
        case .australia: String(localized: "Australia")
        case .europe: String(localized: "Europe (euro)")
        case .other: String(localized: "Another country")
        }
    }

    var currencyCode: String {
        switch self {
        case .us: "USD"
        case .uk: "GBP"
        case .canada: "CAD"
        case .australia: "AUD"
        case .europe: "EUR"
        case .other: Locale.current.currency?.identifier ?? "USD"
        }
    }

    var locale: Locale {
        switch self {
        case .us: Locale(identifier: "en_US")
        case .uk: Locale(identifier: "en_GB")
        case .canada: Locale(identifier: "en_CA")
        case .australia: Locale(identifier: "en_AU")
        case .europe: Locale(identifier: "en_IE")
        case .other: Locale.current
        }
    }

    /// A sensible first choice from the phone's region.
    static func guess(for locale: Locale = .current) -> Country {
        guard let region = locale.region?.identifier else { return .other }
        switch region {
        case "US": return .us
        case "GB": return .uk
        case "CA": return .canada
        case "AU": return .australia
        default:
            return locale.currency?.identifier == "EUR" ? .europe : .other
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
    /// Set for "Another country", so the report shows the same currency on every device.
    var currency: String? = nil

    var currencyCode: String { currency ?? country.currencyCode }

    /// "$", "£", "€", "kr"… for the money field.
    var currencySymbol: String {
        var parts = Locale.Components(locale: .current)
        parts.currency = Locale.Currency(currencyCode)
        return Locale(components: parts).currencySymbol ?? currencyCode
    }

    /// Money in the country's currency, written the way the person's language writes numbers.
    func money(_ cents: Int, locale: Locale = .current) -> String {
        Format.money(cents: cents, currency: currencyCode, locale: locale)
    }
}

/// A family member who gets the monthly report. They never need the app (R6).
struct Recipient: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var name: String
    /// Phone or email, as typed.
    var contact: String
    /// Stored in English ("Sister", "Brother", "Sibling", "Other family"); shown with `relationLabel`.
    var relation: String

    static let relations = ["Sister", "Brother", "Sibling", "Other family"]

    static func label(forRelation relation: String) -> String {
        switch relation {
        case "Sister": String(localized: "Sister")
        case "Brother": String(localized: "Brother")
        case "Sibling": String(localized: "Sibling")
        case "Other family": String(localized: "Other family")
        default: relation
        }
    }

    var relationLabel: String { Self.label(forRelation: relation) }
}

extension CareProfile {
    /// Used until onboarding is done, and in previews.
    static let placeholder = CareProfile(parentName: "", nickname: "Mom", country: .us)
}
