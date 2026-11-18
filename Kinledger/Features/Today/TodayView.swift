import SwiftUI

struct TodayView: View {
    var entries: [Entry] = SampleData.entries
    /// Until local storage lands, the screen shows the mockup month.
    var month: Date = SampleData.month
    var onLogCare: () -> Void = {}

    private var sum: Totals { entries.inMonth(of: month).totals() }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Caring for Mom")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Palette.textSecondary)

                    Card {
                        Text("\(month.formatted(.dateTime.month(.wide))) so far")
                            .font(.headline)
                            .foregroundStyle(Palette.text)
                        HStack(spacing: 8) {
                            StatTile(label: "of care", value: Format.durationSummary(minutes: sum.minutes), tone: .time)
                            StatTile(label: "out of pocket", value: Format.money(cents: sum.outOfPocketCents), tone: .money)
                            StatTile(label: "visits", value: "\(sum.visits)", tone: .visits)
                        }
                    }

                    Button(action: onLogCare) {
                        Text("Log care")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: Metrics.primaryTouch)
                            .foregroundStyle(Palette.onTime)
                            .background(Palette.time, in: Capsule())
                    }
                    .buttonStyle(.plain)

                    Card {
                        Text("Recent")
                            .font(.headline)
                            .foregroundStyle(Palette.text)
                        VStack(spacing: 0) {
                            ForEach(entries.recent(5)) { entry in
                                EntryRow(entry: entry)
                                    .padding(.vertical, 8)
                                if entry.id != entries.recent(5).last?.id {
                                    Divider().overlay(Palette.divider)
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
            .navigationTitle("Today")
        }
    }
}

#Preview {
    TodayView()
}
