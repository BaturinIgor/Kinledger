import SwiftUI

struct EntryRow: View {
    @Environment(\.careProfile) private var profile
    @Environment(\.dynamicTypeSize) private var typeSize
    let entry: Entry
    var showsTime = false

    private var details: String {
        let when = showsTime
            ? entry.occurredAt.formatted(date: .omitted, time: .shortened)
            : entry.occurredAt.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        var parts = [when]
        if let note = entry.note, !note.isEmpty { parts.append(note) }
        if entry.expense?.payer == .parent { parts.append(String(localized: "\(profile.nickname) paid")) }
        if entry.expense?.payer == .repaid { parts.append(String(localized: "repaid")) }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        let large = typeSize.isAccessibilitySize
        let layout = large ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
                           : AnyLayout(HStackLayout(alignment: .center, spacing: 12))
        layout {
            if !large { IconTile(symbol: entry.category.symbol, tone: entry.tone) }
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(Palette.text)
                Text(details)
                    .font(.subheadline)
                    .foregroundStyle(Palette.textSecondary)
                    .lineLimit(large ? 3 : 1)
                    .fixedSize(horizontal: false, vertical: large)
            }
            if !large { Spacer(minLength: 0) }
            VStack(alignment: large ? .leading : .trailing, spacing: 2) {
                if let expense = entry.expense {
                    Text(profile.money(expense.amountCents))
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(expense.payer == .me ? Palette.money : Palette.textSecondary)
                }
                Text(Format.duration(minutes: entry.minutes))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Palette.time)
            }
        }
        .frame(minHeight: Metrics.primaryTouch)
        .accessibilityElement(children: .combine)
    }
}
