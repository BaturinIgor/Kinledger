import SwiftUI

/// Tabs from the mockups: Today, Log, a center + for a new entry, Report, Me.
struct RootView: View {
    enum Tab: Hashable { case today, log, add, report, me }

    @Environment(AppModel.self) private var model
    @Environment(ReportReminderCenter.self) private var reminders
    @State private var selection: Tab = DesignFlags.initialTab
    @State private var isLogging = false

    var body: some View {
        TabView(selection: $selection) {
            TodayView(onLogCare: { isLogging = true })
                .tabItem { Label("Today", systemImage: "house") }
                .tag(Tab.today)

            LogListView()
                .tabItem { Label("Log", systemImage: "list.bullet") }
                .tag(Tab.log)

            Color.clear
                .tabItem { Label("Add", systemImage: "plus.circle.fill") }
                .tag(Tab.add)

            ReportView()
                .tabItem { Label("Report", systemImage: "doc.text") }
                .tag(Tab.report)

            MeView()
                .tabItem { Label("Me", systemImage: "person") }
                .tag(Tab.me)
        }
        .onChange(of: selection) { old, new in
            // The + tab opens the quick log instead of a screen.
            if new == .add {
                selection = old
                isLogging = true
            }
        }
        .onChange(of: reminders.openMonth) { _, month in
            // A tapped reminder opens the report preview; nothing is sent.
            if month != nil { selection = .report }
        }
        .sheet(isPresented: $isLogging) {
            QuickLogView()
        }
        .safeAreaInset(edge: .top) {
            if let problem = model.problem {
                ProblemBanner(text: problem) { model.problem = nil }
            }
        }
    }
}

/// A plain, calm notice. Red is kept for input errors next to a field.
struct ProblemBanner: View {
    let text: String
    let dismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
            Text(text).frame(maxWidth: .infinity, alignment: .leading)
            Button("OK", action: dismiss).fontWeight(.semibold)
        }
        .font(.subheadline)
        .foregroundStyle(Palette.moneyInk)
        .padding(12)
        .background(Palette.moneySoft, in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 16)
    }
}

#Preview {
    RootView().environment(AppModel.preview()).environment(ProStore(unlocked: true))
        .environment(ReportReminderCenter.shared)
}
