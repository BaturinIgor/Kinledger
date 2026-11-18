import SwiftUI

/// Monthly report preview and PDF (R6–R8). The private web link comes with cloud sync.
struct ReportView: View {
    @Environment(AppModel.self) private var model
    @State private var month: Date = Calendar.current.startOfMonth(for: .now)
    @State private var includeNotes = false
    @State private var shared: SharedFile?

    private var report: MonthReport { MonthReport(entries: model.entries, month: month) }

    private var months: [Date] {
        let calendar = Calendar.current
        let current = calendar.startOfMonth(for: .now)
        return (0..<12).compactMap { calendar.date(byAdding: .month, value: -$0, to: current) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Picker("Month", selection: $month) {
                        ForEach(months, id: \.self) { m in
                            Text(m.formatted(.dateTime.month(.wide).year())).tag(m)
                        }
                    }
                    .pickerStyle(.menu)

                    ReportPage(report: report, includeNotes: includeNotes)

                    Toggle("Include my private notes", isOn: $includeNotes)
                        .padding(.horizontal, 4)

                    PrimaryButton(title: "Share PDF") { sharePDF() }
                        .disabled(report.entries.isEmpty)

                    Label("A private link your family opens without the app arrives with cloud backup.",
                          systemImage: "link")
                        .font(.subheadline)
                        .foregroundStyle(Palette.textSecondary)
                }
                .padding(16)
                .frame(maxWidth: Metrics.maxContentWidth)
                .frame(maxWidth: .infinity)
            }
            .background(Palette.background)
            .navigationTitle("Report")
            .sheet(item: $shared) { file in
                ShareSheet(items: [file.url])
            }
        }
    }

    private func sharePDF() {
        do {
            shared = SharedFile(url: try ReportPDF.render(report: report, includeNotes: includeNotes))
        } catch {
            model.problem = "Could not make the PDF: \(error.localizedDescription)"
        }
    }
}

/// The report body. Used on screen and rendered into the PDF, so both always match.
struct ReportPage: View {
    let report: MonthReport
    let includeNotes: Bool
    var parentName = "Mom"

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(parentName)'s care in \(report.month.formatted(.dateTime.month(.wide).year()))")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Palette.text)
                Text(report.headline(parentName: parentName))
                    .font(.body)
                    .foregroundStyle(Palette.textSecondary)
            }

            Card { MonthStats(totals: report.totals) }

            if !report.spending.isEmpty {
                Card {
                    Text("Where my money went").font(.headline).foregroundStyle(Palette.text)
                    ForEach(report.spending, id: \.self) { line in
                        HStack {
                            Text(line.category.label).foregroundStyle(Palette.text)
                            Spacer()
                            Text(Format.money(cents: line.cents))
                                .fontWeight(.semibold)
                                .foregroundStyle(Palette.money)
                        }
                    }
                }
            }

            Card {
                Text("All \(report.entries.count) entries").font(.headline).foregroundStyle(Palette.text)
                ForEach(report.entries) { entry in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(entry.occurredAt.formatted(.dateTime.month(.abbreviated).day()))
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(Palette.textSecondary)
                                .frame(width: 56, alignment: .leading)
                            Text(entry.title).foregroundStyle(Palette.text)
                            Spacer()
                            Text(Format.duration(minutes: entry.minutes)).foregroundStyle(Palette.time)
                            if let expense = entry.expense, expense.payer == .me {
                                Text(Format.money(cents: expense.amountCents)).foregroundStyle(Palette.money)
                            }
                        }
                        .font(.subheadline)
                        if includeNotes, let note = entry.note, !note.isEmpty {
                            Text(note)
                                .font(.footnote)
                                .foregroundStyle(Palette.textSecondary)
                                .padding(.leading, 56)
                        }
                    }
                }
                Text("\(report.receiptCount) receipts kept. Every entry shows when it was logged.")
                    .font(.footnote)
                    .foregroundStyle(Palette.textSecondary)
            }
        }
    }
}

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        self.date(from: dateComponents([.year, .month], from: date)) ?? date
    }
}

#Preview {
    ReportView().environment(AppModel.preview())
}
