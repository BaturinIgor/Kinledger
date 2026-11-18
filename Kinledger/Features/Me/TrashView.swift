import SwiftUI

struct TrashView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        List {
            Section {
                ForEach(model.trash) { item in
                    HStack {
                        EntryRow(entry: item.entry)
                        Button("Restore") { model.restoreFromTrash(item.id) }
                            .font(.callout.weight(.semibold))
                            .buttonStyle(.borderless)
                    }
                }
            } footer: {
                Text("Deleted entries stay here for \(EntryStore.trashDays) days, then they are removed for good. Restored entries keep their history.")
            }
        }
        .overlay {
            if model.trash.isEmpty {
                ContentUnavailableView("Trash is empty", systemImage: "trash")
            }
        }
        .navigationTitle("Trash")
    }
}
