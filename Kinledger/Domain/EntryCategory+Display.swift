import Foundation

extension EntryCategory {
    var label: String {
        switch self {
        case .doctor: "Doctor"
        case .pharmacy: "Pharmacy"
        case .groceries: "Groceries"
        case .overnight: "Overnight"
        case .bills: "Bills & calls"
        case .homeHelp: "Home help"
        case .transport: "Transport"
        case .other: "Other"
        }
    }

    /// SF Symbol name.
    var symbol: String {
        switch self {
        case .doctor: "stethoscope"
        case .pharmacy: "cross.case"
        case .groceries: "cart"
        case .overnight: "moon"
        case .bills: "phone"
        case .homeHelp: "house"
        case .transport: "car"
        case .other: "ellipsis.circle"
        }
    }

    /// Visits default on for categories that usually mean being there in person.
    var usuallyVisit: Bool {
        switch self {
        case .doctor, .groceries, .overnight, .homeHelp: true
        case .pharmacy, .bills, .transport, .other: false
        }
    }

    /// Medical defaults on for the US tax export (R14).
    var usuallyMedical: Bool {
        switch self {
        case .doctor, .pharmacy: true
        default: false
        }
    }
}

extension Entry {
    /// The tone of the row icon: money if it has an expense, visits for nights, time otherwise.
    var tone: Tone {
        if category == .overnight { return .visits }
        return expense == nil ? .time : .money
    }
}
