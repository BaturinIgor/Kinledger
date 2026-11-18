import PhotosUI
import SwiftUI

/// Log what you did in a few taps. Also used to edit an existing entry.
struct QuickLogView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.careProfile) private var profile

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
    /// A receipt already saved for this entry, kept unless replaced or removed.
    @State private var receiptPath: String?
    /// A new photo, written to disk only when the entry is saved.
    @State private var newReceipt: Data?
    @State private var photoItem: PhotosPickerItem?
    @State private var isTakingPhoto = false

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
        _receiptPath = State(initialValue: editing?.expense?.receiptPath)
    }

    private var amount: AmountInput.Result { AmountInput.parse(amountText) }

    private var amountError: String? {
        switch amount {
        case .invalid: String(localized: "Use numbers only, like 42.80.")
        case .suspicious(_, let suggested) where !acceptedLargeAmount:
            String(localized: "That looks too large for one receipt. Did you mean \(profile.money(suggested))?")
        default: nil
        }
    }

    private var canSave: Bool { minutes > 0 || amountCents != nil || newReceipt != nil }

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
                    section(String(localized: "What did you do?")) {
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

                    section(String(localized: "Time")) {
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

                    section(String(localized: "Money")) {
                        HStack {
                            Text(profile.currencySymbol).foregroundStyle(Palette.textSecondary)
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
                                    Button("Use \(profile.money(suggested))") {
                                        amountText = AmountInput.text(cents: suggested)
                                    }
                                    .fontWeight(.semibold)
                                    Spacer()
                                    Button("Keep \(profile.money(typed))") { acceptedLargeAmount = true }
                                }
                                .font(.subheadline)
                            }
                        }
                        if amountCents != nil {
                            Text("Whose money was it?").font(.subheadline.weight(.semibold))
                            HStack(spacing: 8) {
                                ChipButton(title: String(localized: "Mine"), isOn: payer == .me, tone: .money) { payer = .me }
                                ChipButton(title: String(localized: "\(profile.nickname)'s"), isOn: payer == .parent, tone: .money) { payer = .parent }
                                ChipButton(title: String(localized: "Repaid"), isOn: payer == .repaid, tone: .money) { payer = .repaid }
                            }
                            Toggle("Medical expense (tax export)", isOn: $medical)
                        }
                        receiptControls
                    }

                    section(String(localized: "Note")) {
                        TextField("Only you see it unless you share", text: $note, axis: .vertical)
                            .lineLimit(2...5)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                .padding(16)
            }
            .background(Palette.background)
            .navigationTitle(editing == nil ? String(localized: "Quick log") : String(localized: "Edit entry"))
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

    @ViewBuilder
    private var receiptControls: some View {
        if let image = receiptPreview {
            HStack(spacing: 12) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                Text("Receipt attached").font(.subheadline.weight(.medium))
                Spacer()
                Button("Remove") {
                    newReceipt = nil
                    receiptPath = nil
                }
                .font(.subheadline)
            }
        } else {
            HStack(spacing: 8) {
                ChipButton(title: String(localized: "Snap receipt"), symbol: "camera", isOn: false) { isTakingPhoto = true }
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Label("Choose photo", systemImage: "photo")
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 14)
                        .frame(maxWidth: .infinity, minHeight: Metrics.minTouch)
                        .foregroundStyle(Palette.text)
                        .background(Palette.card, in: Capsule())
                        .overlay(Capsule().strokeBorder(Palette.border))
                }
            }
            .onChange(of: photoItem) {
                Task { await loadPhoto() }
            }
            .fullScreenCover(isPresented: $isTakingPhoto) {
                CameraPicker { image in newReceipt = image.receiptJPEG() }
                    .ignoresSafeArea()
            }
        }
    }

    private var receiptPreview: UIImage? {
        if let newReceipt { return UIImage(data: newReceipt) }
        if let receiptPath { return UIImage(contentsOfFile: model.receipts.url(for: receiptPath).path) }
        return nil
    }

    private func loadPhoto() async {
        guard let photoItem,
              let data = try? await photoItem.loadTransferable(type: Data.self),
              let image = UIImage(data: data)
        else { return }
        newReceipt = image.receiptJPEG()
        self.photoItem = nil
    }

    private func pick(_ item: EntryCategory) {
        category = item
        visit = item.usuallyVisit
        medical = item.usuallyMedical
    }

    private func save() {
        var savedReceipt = receiptPath
        if let newReceipt {
            guard let name = model.saveReceipt(newReceipt) else { return }
            savedReceipt = name
        }
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
            expense: (amountCents ?? (savedReceipt == nil ? nil : 0)).map {
                Expense(amountCents: $0, payer: payer, medical: medical, receiptPath: savedReceipt)
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
