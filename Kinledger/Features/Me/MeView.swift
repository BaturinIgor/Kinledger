import SwiftUI

struct MeView: View {
    @Environment(AppModel.self) private var model

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
        }
    }
}
