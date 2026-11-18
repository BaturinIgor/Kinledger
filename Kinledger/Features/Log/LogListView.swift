import SwiftUI

/// Every entry, grouped by the day the care happened.
struct LogListView: View {
    @Environment(AppModel.self) private var model
    @State private var trashed: UUID?

    private var days: [DayGroup] { DayGroup.make(model.entries) }

    var body: some View {
        NavigationStack {
            Group {
                if model.entries.isEmpty {
                    ContentUnavailableView(
                        "No entries yet",
                        systemImage: "list.bullet",
                        description: Text("Everything you log shows up here, newest first.")
                    )
                } else {
                    List {
                        ForEach(days) { group in
                            Section(group.day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())) {
                                ForEach(group.entries) { entry in
                                    NavigationLink(value: entry.id) {
                                        EntryRow(entry: entry, showsTime: true)
                                    }
                                    .swipeActions {
                                        Button("Trash", systemImage: "trash", role: .destructive) {
                                            moveToTrash(entry.id)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Palette.background)
            .navigationTitle("Log")
            .navigationDestination(for: UUID.self) { id in
                EntryDetailView(entryID: id)
            }
            .overlay(alignment: .bottom) {
                if let trashed {
                    Toast(text: String(localized: "Moved to trash. Kept for 30 days."), action: String(localized: "Undo")) {
                        model.restoreFromTrash(trashed)
                        self.trashed = nil
                    }
                }
            }
            .animation(.default, value: trashed)
        }
    }

    private func moveToTrash(_ id: UUID) {
        model.moveToTrash(id)
        trashed = id
        Task {
            try? await Task.sleep(for: .seconds(6))
            if trashed == id { trashed = nil }
        }
    }
}

#Preview {
    LogListView().environment(AppModel.preview())
}

/// Entries that happened on one calendar day.
struct DayGroup: Identifiable {
    let day: Date
    let entries: [Entry]
    var id: Date { day }

    /// Newest day first; entries keep the order they came in.
    static func make(_ entries: [Entry], calendar: Calendar = .current) -> [DayGroup] {
        let grouped = Dictionary(grouping: entries) { calendar.startOfDay(for: $0.occurredAt) }
        return grouped.keys.sorted(by: >).map { DayGroup(day: $0, entries: grouped[$0] ?? []) }
    }
}
