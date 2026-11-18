import SwiftUI

/// US medical-expense export (R14): a CSV and the receipts, for a tax preparer.
struct TaxExportView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.careProfile) private var profile
    @State private var year = Calendar.current.component(.year, from: .now)
    @State private var shared: SharedFile?

    private var summary: TaxYearSummary { TaxYearSummary(entries: model.entries, year: year) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Picker("Year", selection: $year) {
                    let current = Calendar.current.component(.year, from: .now)
                    ForEach([current, current - 1], id: \.self) { Text(String($0)).tag($0) }
                }
                .pickerStyle(.segmented)

                Card {
                    Text(profile.money(summary.totalCents))
                        .font(.largeTitle.weight(.semibold))
                        .foregroundStyle(Palette.money)
                    Text("Paid by you and marked medical. \(summary.expenses.count) expenses, \(summary.withReceipt) with receipts.")
                        .foregroundStyle(Palette.text)
                    if summary.withoutReceipt > 0 {
                        Label("\(summary.withoutReceipt) expenses have no receipt. They export as \"no receipt\".",
                              systemImage: "exclamationmark.triangle")
                            .font(.subheadline)
                            .foregroundStyle(Palette.moneyInk)
                            .padding(12)
                            .background(Palette.moneySoft, in: RoundedRectangle(cornerRadius: 12))
                    }
                }

                Text("You get a spreadsheet (date, description, category, amount, receipt file) and a folder of receipt photos named to match.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.textSecondary)
                Text("A record of what you paid, not tax advice.")
                    .font(.footnote)
                    .foregroundStyle(Palette.textSecondary)

                PrimaryButton(title: String(localized: "Export for \(String(year))")) {
                    if let url = model.exportTaxYear(year) { shared = SharedFile(url: url) }
                }
                .disabled(summary.expenses.isEmpty)
            }
            .padding(16)
        }
        .background(Palette.background)
        .navigationTitle("Tax export")
        .sheet(item: $shared) { file in ShareSheet(items: [file.url]) }
    }
}
