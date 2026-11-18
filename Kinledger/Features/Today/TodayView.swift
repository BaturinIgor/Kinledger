import SwiftUI

struct TodayView: View {
    @Environment(AppModel.self) private var model
    var onLogCare: () -> Void = {}
    var now: Date = .now

    private var month: [Entry] { model.entries.inMonth(of: now) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(now.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Palette.textSecondary)

                    Card {
                        Text("\(now.formatted(.dateTime.month(.wide))) so far")
                            .font(.headline)
                            .foregroundStyle(Palette.text)
                        MonthStats(totals: month.totals())
                        if month.isEmpty {
                            Text("Totals fill in as you log. Most people add the first entry in under 10 seconds.")
                                .font(.subheadline)
                                .foregroundStyle(Palette.textSecondary)
                        }
                    }

                    if model.entries.isEmpty {
                        EmptyToday(onLogCare: onLogCare)
                    } else {
                        PrimaryButton(title: "Log care", action: onLogCare)
                        Text("Recent")
                            .font(.headline)
                            .foregroundStyle(Palette.text)
                        Card {
                            let recent = model.entries.recent(5)
                            VStack(spacing: 0) {
                                ForEach(recent) { entry in
                                    NavigationLink(value: entry.id) {
                                        EntryRow(entry: entry)
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.vertical, 6)
                                    if entry.id != recent.last?.id {
                                        Divider().overlay(Palette.divider)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: Metrics.maxContentWidth)
                .frame(maxWidth: .infinity)
            }
            .background(Palette.background)
            .navigationTitle("Mom's care")
            .navigationDestination(for: UUID.self) { id in
                EntryDetailView(entryID: id)
            }
        }
    }
}

struct MonthStats: View {
    let totals: Totals

    var body: some View {
        HStack(spacing: 8) {
            StatTile(label: "of care", value: Format.durationSummary(minutes: totals.minutes), tone: .time)
            StatTile(label: "I paid", value: Format.money(cents: totals.outOfPocketCents), tone: .money)
            StatTile(label: "visits", value: "\(totals.visits)", tone: .visits)
        }
    }
}

private struct EmptyToday: View {
    let onLogCare: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            IconTile(symbol: "clock", tone: .time, size: 64)
            Text("Log your first entry")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Palette.text)
            Text("A drive to the doctor, a pharmacy run, a night at her place. Tap + and pick what you did.")
                .font(.body)
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
            PrimaryButton(title: "Log care", action: onLogCare)
        }
        .padding(.top, 32)
        .frame(maxWidth: .infinity)
    }
}

struct PrimaryButton: View {
    let title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: Metrics.primaryTouch)
                .foregroundStyle(Palette.onTime)
                .background(Palette.time, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

#Preview("With entries") {
    TodayView(now: SampleData.month).environment(AppModel.preview())
}

#Preview("First day") {
    TodayView().environment(AppModel.preview([]))
}
