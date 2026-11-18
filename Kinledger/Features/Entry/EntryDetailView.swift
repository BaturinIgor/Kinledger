import SwiftUI

/// One entry with its edit history. The history is what makes the report trustworthy (R9).
struct EntryDetailView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.careProfile) private var profile
    let entryID: UUID
    @State private var isEditing = false

    var body: some View {
        if let entry = model.entry(entryID) {
            content(entry)
        } else {
            ContentUnavailableView("Entry not found", systemImage: "questionmark.circle",
                                   description: Text("It may have been moved to the trash."))
        }
    }

    private func content(_ entry: Entry) -> some View {
        let history = model.history(of: entry.id)
        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Card {
                    HStack(spacing: 12) {
                        IconTile(symbol: entry.category.symbol, tone: entry.tone, size: 48)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.title).font(.title3.weight(.semibold)).foregroundStyle(Palette.text)
                            Text(entry.occurredAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.subheadline).foregroundStyle(Palette.textSecondary)
                        }
                    }
                    HStack(spacing: 8) {
                        StatTile(label: "time", value: Format.duration(minutes: entry.minutes), tone: .time)
                        if let expense = entry.expense {
                            StatTile(label: payerLabel(expense.payer), value: profile.money(expense.amountCents), tone: .money)
                        }
                        if entry.visit {
                            StatTile(label: "visit", value: "1", tone: .visits)
                        }
                    }
                    if let note = entry.note, !note.isEmpty {
                        Text("Note (private): \(note)").font(.body).foregroundStyle(Palette.text)
                    }
                    if let name = entry.expense?.receiptPath,
                       let image = UIImage(contentsOfFile: model.receipts.url(for: name).path) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 280)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .accessibilityLabel("Receipt photo")
                    }
                }

                Label("History", systemImage: "clock.arrow.circlepath")
                    .font(.headline)
                    .foregroundStyle(Palette.text)
                Card {
                    ForEach(history) { revision in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(Changes.summary(from: revision.previous, to: entry, money: profile.money))
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(Palette.text)
                            HStack {
                                Text("Changed \(revision.replacedAt.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.subheadline).foregroundStyle(Palette.textSecondary)
                                Spacer()
                                Button("Restore this version") { model.restore(revision) }
                                    .font(.subheadline.weight(.semibold))
                            }
                        }
                        Divider().overlay(Palette.divider)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Logged").font(.callout.weight(.semibold)).foregroundStyle(Palette.text)
                        Text(Changes.loggedLine(entry)).font(.subheadline).foregroundStyle(Palette.textSecondary)
                    }
                }

                Button {
                    model.moveToTrash(entry.id)
                    dismiss()
                } label: {
                    Label("Move to trash", systemImage: "trash")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: Metrics.primaryTouch)
                        .foregroundStyle(Palette.text)
                        .background(Palette.card, in: Capsule())
                        .overlay(Capsule().strokeBorder(Palette.border))
                }
                .buttonStyle(.plain)
            }
            .padding(16)
        }
        .background(Palette.background)
        .navigationTitle("Entry")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button("Edit") { isEditing = true }
        }
        .sheet(isPresented: $isEditing) {
            QuickLogView(editing: entry)
        }
    }

    private func payerLabel(_ payer: Payer) -> String {
        switch payer {
        case .me: "I paid"
        case .parent: "she paid"
        case .repaid: "repaid"
        }
    }
}

/// Plain-language descriptions of what changed between two versions.
enum Changes {
    static func summary(from old: Entry, to new: Entry, money: (Int) -> String = { Format.money(cents: $0) }) -> String {
        var parts: [String] = []
        if old.title != new.title { parts.append("Title \(old.title) → \(new.title)") }
        if old.minutes != new.minutes {
            parts.append("Time \(Format.duration(minutes: old.minutes)) → \(Format.duration(minutes: new.minutes))")
        }
        if old.expense?.amountCents != new.expense?.amountCents {
            let before = old.expense.map { money($0.amountCents) } ?? "none"
            let after = new.expense.map { money($0.amountCents) } ?? "none"
            parts.append("Amount \(before) → \(after)")
        }
        if old.occurredAt != new.occurredAt { parts.append("Date changed") }
        if old.note != new.note { parts.append("Note changed") }
        return parts.isEmpty ? "Details changed" : parts.joined(separator: ", ")
    }

    static func loggedLine(_ entry: Entry, calendar: Calendar = .current) -> String {
        let when = entry.loggedAt.formatted(date: .abbreviated, time: .shortened)
        let sameDay = calendar.isDate(entry.loggedAt, inSameDayAs: entry.occurredAt)
        return sameDay ? "\(when), the same day" : when
    }
}

#Preview {
    let model = AppModel.preview()
    return NavigationStack {
        EntryDetailView(entryID: model.entries[0].id)
    }
    .environment(model)
}
