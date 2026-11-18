import SwiftUI

struct MeView: View {
    @Environment(AppModel.self) private var model
    @Environment(ProStore.self) private var pro
    @State private var showPaywall = false
    @State private var shared: SharedFile?

    var body: some View {
        NavigationStack {
            List {
                CloudBackupSection()
                Section("Family on the report") {
                    ForEach(model.recipients) { person in
                        LabeledContent(person.name, value: person.relationLabel)
                    }
                    .onDelete { offsets in
                        for index in offsets { model.deleteRecipient(model.recipients[index].id) }
                    }
                    NavigationLink {
                        AddRecipientView()
                    } label: {
                        Label("Add a person", systemImage: "plus")
                    }
                }
                Section("Kinledger Pro") {
                    if pro.isPro {
                        Label("Pro is on. Thank you.", systemImage: "checkmark.seal")
                    } else {
                        Button { showPaywall = true } label: {
                            Label("Family report and tax export", systemImage: "sparkles")
                        }
                    }
                }
                Section {
                    if model.careProfile.country.hasTaxExport {
                        if pro.isPro {
                            NavigationLink {
                                TaxExportView()
                            } label: {
                                Label("Tax export", systemImage: "doc.text")
                            }
                        } else {
                            Button { showPaywall = true } label: {
                                Label("Tax export · Pro", systemImage: "doc.text")
                            }
                        }
                    }
                    Button {
                        if let url = model.exportAllData() { shared = SharedFile(url: url) }
                    } label: {
                        Label("Export all my data", systemImage: "square.and.arrow.up")
                    }
                } footer: {
                    Text("A spreadsheet of every entry plus all receipt photos. Free, any time.")
                }
                Section {
                    NavigationLink {
                        TrashView()
                    } label: {
                        LabeledContent {
                            Text("\(model.trash.count)")
                        } label: {
                            Label("Trash", systemImage: "trash")
                        }
                    }
                    Label("Notes are private by default", systemImage: "lock")
                    Link(destination: Links.privacy) {
                        Label("Privacy Policy", systemImage: "hand.raised")
                    }
                    Link(destination: Links.support) {
                        Label("Help and contact", systemImage: "questionmark.circle")
                    }
                }
            }
            .navigationTitle("Me")
            .sheet(item: $shared) { file in ShareSheet(items: [file.url]) }
            .sheet(isPresented: $showPaywall) { PaywallView() }
        }
    }
}

struct AddRecipientView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var person = Recipient(id: UUID(), name: "", contact: "", relation: "Sibling")

    var body: some View {
        ScrollView {
            RecipientEditor(person: $person) { dismiss() }
                .padding(16)
        }
        .background(Palette.background)
        .navigationTitle("Add a person")
        .toolbar {
            Button("Save") {
                model.saveRecipient(person)
                dismiss()
            }
            .disabled(person.name.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }
}
