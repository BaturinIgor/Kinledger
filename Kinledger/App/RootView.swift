import SwiftUI

/// Four tabs from the mockups: Today, Log, Report, Me.
struct RootView: View {
    enum Tab: Hashable { case today, log, report, me }

    @State private var selection: Tab = .today

    var body: some View {
        TabView(selection: $selection) {
            TodayView(onLogCare: { selection = .log })
                .tabItem { Label("Today", systemImage: "house") }
                .tag(Tab.today)

            PlaceholderView(
                title: "Log care",
                message: "Quick log: what, how long, any money spent. Coming next."
            )
            .tabItem { Label("Log", systemImage: "plus.circle") }
            .tag(Tab.log)

            PlaceholderView(
                title: "Monthly report",
                message: "A private link your family can open without installing anything. Coming next."
            )
            .tabItem { Label("Report", systemImage: "doc.text") }
            .tag(Tab.report)

            PlaceholderView(
                title: "Me",
                message: "Account, backups, export and settings. Your data is yours: export any time."
            )
            .tabItem { Label("Me", systemImage: "person.crop.circle") }
            .tag(Tab.me)
        }
    }
}

#Preview {
    RootView()
}
