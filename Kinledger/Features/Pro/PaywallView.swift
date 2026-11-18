import StoreKit
import SwiftUI

/// The Pro screen from the mockups. Says plainly what stays free.
struct PaywallView: View {
    @Environment(ProStore.self) private var pro
    @Environment(\.dismiss) private var dismiss
    @State private var choice = ProStore.yearlyID

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Send the monthly report with Pro")
                        .font(.largeTitle.weight(.semibold))
                        .foregroundStyle(Palette.text)
                    VStack(alignment: .leading, spacing: 12) {
                        Benefit(text: "Monthly report link and PDF for your family")
                        Benefit(text: "US medical-expense export with receipts")
                        Benefit(text: "Unlimited receipt photos")
                    }
                    Text("Free forever: logging, totals, backup and exporting all your data.")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(Palette.text)

                    if pro.isLoading {
                        ProgressView().frame(maxWidth: .infinity)
                    } else if pro.products.isEmpty {
                        Text("Prices are not available right now. Try again later.")
                            .font(.subheadline).foregroundStyle(Palette.textSecondary)
                    } else {
                        if let yearly = pro.yearly {
                            PlanRow(product: yearly, subtitle: yearlySubtitle(yearly), badge: savingsBadge,
                                    isOn: choice == yearly.id) { choice = yearly.id }
                        }
                        if let monthly = pro.monthly {
                            PlanRow(product: monthly, subtitle: "Cancel any time", badge: nil,
                                    isOn: choice == monthly.id) { choice = monthly.id }
                        }
                    }

                    if let message = pro.message {
                        Text(message).font(.subheadline).foregroundStyle(Palette.textSecondary)
                    }
                }
                .padding(20)
            }
            .background(Palette.background)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    PrimaryButton(title: "Try free for 7 days") {
                        guard let product = pro.products.first(where: { $0.id == choice }) else { return }
                        Task {
                            await pro.purchase(product)
                            if pro.isPro { dismiss() }
                        }
                    }
                    .disabled(pro.products.isEmpty)
                    Text("Free for 7 days, then the plan you chose. Cancel in Settings any time before the trial ends.")
                        .font(.footnote)
                        .foregroundStyle(Palette.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(20)
                .background(Palette.background)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    Button("Restore") { Task { await pro.restore() } }
                }
            }
            .task { if pro.products.isEmpty { await pro.loadProducts() } }
        }
    }

    private var savingsBadge: String? {
        guard let monthly = pro.monthly, let yearly = pro.yearly else { return nil }
        let percent = Pricing.yearlySavingsPercent(monthly: monthly.price, yearly: yearly.price)
        return percent > 0 ? "Save \(percent)%" : nil
    }

    private func yearlySubtitle(_ yearly: Product) -> String {
        let perMonth = (yearly.price / 12).formatted(yearly.priceFormatStyle)
        return "\(perMonth) a month, billed once a year"
    }
}

private struct Benefit: View {
    let text: String
    var body: some View {
        Label {
            Text(text).foregroundStyle(Palette.text)
        } icon: {
            Image(systemName: "checkmark").fontWeight(.bold).foregroundStyle(Palette.time)
        }
    }
}

private struct PlanRow: View {
    let product: Product
    let subtitle: String
    let badge: String?
    let isOn: Bool
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(product.id == ProStore.yearlyID ? "Yearly" : "Monthly").font(.headline)
                        if let badge {
                            Text(badge)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Palette.onTime)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Palette.time, in: Capsule())
                        }
                    }
                    Text(subtitle).font(.subheadline).foregroundStyle(Palette.textSecondary)
                }
                Spacer()
                Text(product.displayPrice).font(.title3.weight(.semibold))
            }
            .foregroundStyle(Palette.text)
            .padding(16)
            .background(Palette.card, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16)
                .strokeBorder(isOn ? Palette.time : Palette.border, lineWidth: isOn ? 2 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
