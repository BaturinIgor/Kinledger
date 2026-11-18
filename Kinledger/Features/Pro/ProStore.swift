import Foundation
import Observation
import StoreKit

/// Kinledger Pro: $9.99 a month or $79 a year, 7-day free trial (set up in App Store Connect).
///
/// Pro unlocks the monthly report for family and the tax export. Logging, totals, backup and
/// exporting all data stay free forever, and ending Pro never locks old entries away.
@MainActor
@Observable
final class ProStore {
    nonisolated static let monthlyID = "app.kinledger.pro.monthly"
    nonisolated static let yearlyID = "app.kinledger.pro.yearly"
    nonisolated static let productIDs: Set<String> = [monthlyID, yearlyID]

    private(set) var products: [Product] = []
    private(set) var isPro = false
    private(set) var isLoading = false
    var message: String?

    private var updates: Task<Void, Never>?

    init(unlocked: Bool = false) {
        isPro = unlocked
    }

    /// Call once at launch: loads prices, checks what the person already owns, and listens for renewals.
    func start() {
        guard updates == nil else { return }
        updates = Task { [weak self] in
            for await update in Transaction.updates {
                if case .verified(let transaction) = update {
                    await transaction.finish()
                }
                await self?.refreshEntitlements()
            }
        }
        Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }

    var monthly: Product? { products.first { $0.id == Self.monthlyID } }
    var yearly: Product? { products.first { $0.id == Self.yearlyID } }

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        do {
            products = try await Product.products(for: Self.productIDs)
        } catch {
            message = "Prices could not load. Check the connection and try again."
        }
    }

    func refreshEntitlements() async {
        var owned: Set<String> = []
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result, transaction.revocationDate == nil {
                owned.insert(transaction.productID)
            }
        }
        isPro = Self.unlocks(owned)
    }

    nonisolated static func unlocks(_ owned: Set<String>) -> Bool {
        !owned.isDisjoint(with: productIDs)
    }

    func purchase(_ product: Product) async {
        do {
            switch try await product.purchase() {
            case .success(.verified(let transaction)):
                await transaction.finish()
                await refreshEntitlements()
            case .success(.unverified):
                message = "The App Store could not confirm this purchase."
            case .pending:
                message = "Waiting for approval. Pro turns on as soon as it is approved."
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            message = "The purchase did not go through: \(error.localizedDescription)"
        }
    }

    func restore() async {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            if !isPro { message = "No Pro subscription was found for this Apple ID." }
        } catch {
            message = "Could not restore: \(error.localizedDescription)"
        }
    }
}

enum Pricing {
    /// How much the yearly plan saves against twelve months, rounded down: $79 vs $9.99 → 34.
    static func yearlySavingsPercent(monthly: Decimal, yearly: Decimal) -> Int {
        let fullYear = monthly * 12
        guard fullYear > 0 else { return 0 }
        var saving = (fullYear - yearly) / fullYear * 100
        // Round first: NSDecimalNumber.intValue returns 0 for decimals with a long mantissa.
        var whole = Decimal()
        NSDecimalRound(&whole, &saving, 0, .down)
        return max(0, Int(truncating: whole as NSNumber))
    }
}
