import SwiftUI

struct TrashView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        List {
            Section {
                ForEach(model.trash) { item in
                    // Restore goes under the entry with large text, so the entry keeps the full width.
                    let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                                                              : AnyLayout(HStackLayout())
                    layout {
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
