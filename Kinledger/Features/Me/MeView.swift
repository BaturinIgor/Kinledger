import SwiftUI

struct MeView: View {
    @Environment(AppModel.self) private var model
    @State private var shared: SharedFile?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Saved on this iPhone")
                            Text("\(model.entries.count) entries. Cloud backup comes with sign-in.")
                                .font(.subheadline)
                                .foregroundStyle(Palette.textSecondary)
                        }
                    } icon: {
                        Image(systemName: "iphone").foregroundStyle(Palette.time)
                    }
                }
                Section {
                    NavigationLink {
                        TaxExportView()
                    } label: {
                        Label("Tax export", systemImage: "doc.text")
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
                }
            }
            .navigationTitle("Me")
            .sheet(item: $shared) { file in ShareSheet(items: [file.url]) }
        }
    }
}
