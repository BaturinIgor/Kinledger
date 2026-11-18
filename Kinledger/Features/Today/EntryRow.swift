import SwiftUI

struct EntryRow: View {
    let entry: Entry

    private var details: String {
        let when = entry.occurredAt.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        return [when, entry.note].compactMap { $0 }.joined(separator: " · ")
    }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(Palette.text)
                Text(details)
                    .font(.subheadline)
                    .foregroundStyle(Palette.textSecondary)
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 2) {
                Text(Format.duration(minutes: entry.minutes))
                    .foregroundStyle(Palette.time)
                if let expense = entry.expense {
                    Text(Format.money(cents: expense.amountCents) + (expense.payer == .me ? "" : " · not mine"))
                        .foregroundStyle(Palette.money)
                }
            }
            .font(.subheadline.weight(.medium))
        }
        .frame(minHeight: Metrics.primaryTouch)
        .accessibilityElement(children: .combine)
    }
}
