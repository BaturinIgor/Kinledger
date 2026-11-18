import SwiftUI

/// Log what you did in a few taps. Also used to edit an existing entry.
struct QuickLogView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    private let editing: Entry?
    @State private var category: EntryCategory
    @State private var title: String
    @State private var minutes: Int
    @State private var occurredAt: Date
    @State private var visit: Bool
    @State private var amountText: String
    @State private var payer: Payer
    @State private var medical: Bool
    @State private var note: String
    @State private var acceptedLargeAmount = false

    init(editing: Entry? = nil) {
        self.editing = editing
        let category = editing?.category ?? .doctor
        _category = State(initialValue: category)
        _title = State(initialValue: editing?.title ?? "")
        _minutes = State(initialValue: editing?.minutes ?? 60)
        _occurredAt = State(initialValue: editing?.occurredAt ?? .now)
        _visit = State(initialValue: editing?.visit ?? category.usuallyVisit)
        _amountText = State(initialValue: editing?.expense.map { AmountInput.text(cents: $0.amountCents) } ?? "")
        _payer = State(initialValue: editing?.expense?.payer ?? .me)
        _medical = State(initialValue: editing?.expense?.medical ?? category.usuallyMedical)
        _note = State(initialValue: editing?.note ?? "")
    }

    private var amount: AmountInput.Result { AmountInput.parse(amountText) }

    private var amountError: String? {
        switch amount {
        case .invalid: "Use numbers only, like 42.80."
        case .suspicious(_, let suggested) where !acceptedLargeAmount:
            "That looks too large for one receipt. Did you mean \(Format.money(cents: suggested))?"
        default: nil
        }
    }

    private var canSave: Bool { minutes > 0 || amountCents != nil }

    private var amountCents: Int? {
        switch amount {
        case .cents(let cents): cents
        case .suspicious(let typed, _) where acceptedLargeAmount: typed
        default: nil
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    section("What did you do?") {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 8)], spacing: 8) {
                            ForEach(EntryCategory.allCases, id: \.self) { item in
                                ChipButton(title: item.label, symbol: item.symbol, isOn: item == category) {
                                    pick(item)
                                }
                            }
                        }
                        TextField(category.label, text: $title)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityLabel("Title")
                    }

                    section("Time") {
                        HStack(spacing: 8) {
                            ForEach([30, 60, 120, 240], id: \.self) { preset in
                                ChipButton(title: Format.duration(minutes: preset), isOn: minutes == preset) {
                                    minutes = preset
                                }
                            }
                        }
                        Stepper("\(Format.duration(minutes: minutes))", value: $minutes, in: 0...(24 * 60), step: 15)
                        DatePicker("When", selection: $occurredAt)
                        Toggle("Counts as a visit", isOn: $visit)
                    }

                    section("Money") {
                        HStack {
                            Text("$").foregroundStyle(Palette.textSecondary)
                            TextField("0.00", text: $amountText)
                                .keyboardType(.decimalPad)
                                .onChange(of: amountText) { acceptedLargeAmount = false }
                        }
                        .padding(.horizontal, 14)
                        .frame(minHeight: 52)
                        .background(Palette.card, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(amountError == nil ? Palette.border : Palette.error, lineWidth: amountError == nil ? 1 : 2)
                        )
                        if let amountError {
                            Label(amountError, systemImage: "exclamationmark.triangle")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Palette.error)
                            if case .suspicious(let typed, let suggested) = amount {
                                HStack {
                                    Button("Use \(Format.money(cents: suggested))") {
                                        amountText = AmountInput.text(cents: suggested)
                                    }
                                    .fontWeight(.semibold)
                                    Spacer()
                                    Button("Keep \(Format.money(cents: typed))") { acceptedLargeAmount = true }
                                }
                                .font(.subheadline)
                            }
                        }
                        if amountCents != nil {
                            Text("Whose money was it?").font(.subheadline.weight(.semibold))
                            HStack(spacing: 8) {
                                ChipButton(title: "Mine", isOn: payer == .me, tone: .money) { payer = .me }
                                ChipButton(title: "Hers", isOn: payer == .parent, tone: .money) { payer = .parent }
                                ChipButton(title: "Repaid", isOn: payer == .repaid, tone: .money) { payer = .repaid }
                            }
                            Toggle("Medical expense (tax export)", isOn: $medical)
                        }
                    }

                    section("Note") {
                        TextField("Only you see it unless you share", text: $note, axis: .vertical)
                            .lineLimit(2...5)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                .padding(16)
            }
            .background(Palette.background)
            .navigationTitle(editing == nil ? "Quick log" : "Edit entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .fontWeight(.semibold)
                        .disabled(!canSave || amountError != nil)
                }
            }
        }
    }

    private func pick(_ item: EntryCategory) {
        category = item
        visit = item.usuallyVisit
        medical = item.usuallyMedical
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let entry = Entry(
            id: editing?.id ?? UUID(),
            category: category,
            title: trimmedTitle.isEmpty ? category.label : trimmedTitle,
            occurredAt: occurredAt,
            loggedAt: editing?.loggedAt ?? .now,
            minutes: minutes,
            visit: visit,
            expense: amountCents.map {
                Expense(amountCents: $0, payer: payer, medical: medical, receiptPath: editing?.expense?.receiptPath)
            },
            note: trimmedNote.isEmpty ? nil : trimmedNote
        )
        if model.save(entry) { dismiss() }
    }

    @ViewBuilder
    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline).foregroundStyle(Palette.text)
            content()
        }
    }
}

/// A 44 pt pill used for choices. Filled when selected.
struct ChipButton: View {
    let title: String
    var symbol: String? = nil
    let isOn: Bool
    var tone: Tone = .time
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let symbol { Image(systemName: symbol) }
                Text(title).lineLimit(1).minimumScaleFactor(0.8)
            }
            .font(.subheadline.weight(isOn ? .semibold : .medium))
            .padding(.horizontal, 14)
            .frame(minHeight: Metrics.minTouch)
            .frame(maxWidth: symbol == nil ? nil : .infinity)
            .foregroundStyle(isOn ? Color.white : Palette.text)
            .background(isOn ? tone.color : Palette.card, in: Capsule())
            .overlay(Capsule().strokeBorder(isOn ? Color.clear : Palette.border))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

#Preview {
    QuickLogView().environment(AppModel.preview([]))
}
