import SwiftUI

/// Two steps, under a minute (R1): who you care for, then who gets the report.
struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    @State private var step = DesignFlags.onboardingStep
    @State private var parentName = ""
    @State private var nickname = ""
    @State private var country: Country = .guess()
    @State private var people: [Recipient] = []
    @State private var isRestoring = false

    private var canContinue: Bool {
        !parentName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var profile: CareProfile {
        let name = parentName.trimmingCharacters(in: .whitespaces)
        let called = nickname.trimmingCharacters(in: .whitespaces)
        return CareProfile(
            parentName: name,
            nickname: called.isEmpty ? name : called,
            country: country,
            currency: country == .other ? Locale.current.currency?.identifier : nil
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("\(step) of 2")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Palette.textSecondary)
                    if step == 1 { stepOne } else { stepTwo }
                }
                .padding(20)
                .frame(maxWidth: Metrics.maxContentWidth)
                .frame(maxWidth: .infinity)
            }
            .background(Palette.background)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    if step == 1 {
                        PrimaryButton(title: String(localized: "Next")) { step = 2 }
                            .disabled(!canContinue)
                            .opacity(canContinue ? 1 : 0.5)
                    } else {
                        PrimaryButton(title: String(localized: "Start logging"), action: finish)
                        Button("I'll add them later", action: finish)
                            .frame(minHeight: Metrics.minTouch)
                    }
                }
                .padding(20)
                .background(Palette.background)
            }
            .toolbar {
                if step == 2 {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Back") { step = 1 }
                    }
                } else if model.cloud.isConfigured {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Restore") { isRestoring = true }
                    }
                }
            }
            .sheet(isPresented: $isRestoring) { RestoreSheet() }
        }
    }

    private var stepOne: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Who are you caring for?")
                .font(.largeTitle.weight(.semibold))
                .foregroundStyle(Palette.text)
            LabeledField(label: String(localized: "Their name")) {
                TextField("Margaret", text: $parentName)
                    .textContentType(.name)
            }
            LabeledField(label: String(localized: "What you call them"), hint: String(localized: "Used in the app and the report, like \"Mom's care in November\".")) {
                TextField("Mom", text: $nickname)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Country for money and tax").font(.subheadline.weight(.semibold))
                Picker("Country", selection: $country) {
                    ForEach(Country.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                .pickerStyle(.menu)
            }
        }
    }

    private var stepTwo: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Who should see how \(profile.nickname) is doing?")
                .font(.largeTitle.weight(.semibold))
                .foregroundStyle(Palette.text)
            Text("Once a month they get a private report with your hours and costs. They don't need the app or an account.")
                .foregroundStyle(Palette.textSecondary)
            ForEach($people) { $person in
                RecipientEditor(person: $person) {
                    people.removeAll { $0.id == person.id }
                }
            }
            Button {
                people.append(Recipient(id: UUID(), name: "", contact: "", relation: "Sibling"))
            } label: {
                Label("Add a person", systemImage: "plus")
                    .frame(minHeight: Metrics.minTouch)
            }
            Text("Nothing is sent until you review it. You can turn the link off any time.")
                .font(.subheadline)
                .foregroundStyle(Palette.textSecondary)
        }
    }

    private func finish() {
        for person in people where !person.name.trimmingCharacters(in: .whitespaces).isEmpty {
            model.saveRecipient(person)
        }
        model.saveProfile(profile)
    }
}

struct LabeledField<Field: View>: View {
    let label: String
    var hint: String? = nil
    @ViewBuilder var field: Field

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.text)
            field
                .padding(.horizontal, 14)
                .frame(minHeight: 52)
                .background(Palette.card, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Palette.border))
            if let hint {
                Text(hint).font(.subheadline).foregroundStyle(Palette.textSecondary)
            }
        }
    }
}

struct RecipientEditor: View {
    @Binding var person: Recipient
    let onRemove: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize

    private var relationOptions: some View {
        ForEach(Recipient.relations, id: \.self) { Text(Recipient.label(forRelation: $0)).tag($0) }
    }

    var body: some View {
        Card {
            HStack {
                Text(person.name.isEmpty ? String(localized: "New person") : person.name).font(.headline)
                Spacer()
                Button("Remove", role: .destructive, action: onRemove).font(.subheadline)
            }
            LabeledField(label: String(localized: "Name")) { TextField("Dave", text: $person.name) }
            LabeledField(label: String(localized: "Phone or email")) {
                TextField("dave@example.com", text: $person.contact)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
            }
            // Segments cut their words at accessibility text sizes; a menu shows them whole.
            if typeSize.isAccessibilitySize {
                Picker("Relation", selection: $person.relation) { relationOptions }
                    .pickerStyle(.menu)
            } else {
                Picker("Relation", selection: $person.relation) { relationOptions }
                    .pickerStyle(.segmented)
            }
        }
    }
}

#Preview {
    OnboardingView().environment(AppModel.preview([], onboarded: false))
}
