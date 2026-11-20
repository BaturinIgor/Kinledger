import SwiftUI

@main
struct KinledgerApp: App {
    @State private var model = KinledgerApp.makeModel()
    @State private var pro = ProStore(unlocked: DesignFlags.pro)
    @State private var reminders = ReportReminderCenter.shared
    @Environment(\.scenePhase) private var scenePhase

    init() {
        if !ScreenshotData.isActive {
            Diagnostics.shared.start()
            ReportReminderCenter.shared.start()
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if model.profile == nil {
                    OnboardingView()
                } else {
                    RootView()
                }
            }
                .designPresenter()
                .environment(model)
                .environment(pro)
                .environment(reminders)
                .task { pro.start() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { model.cloud.syncSoon(delay: .zero) }
                    // Entries logged today decide whether next 1st's reminder is worth sending.
                    if phase != .inactive, !ScreenshotData.isActive {
                        Task { await reminders.reschedule(entries: model.entries) }
                    }
                }
                .environment(\.careProfile, model.careProfile)
                .tint(Palette.time)
        }
    }

    private static func makeModel() -> AppModel {
        #if DEBUG
        if DesignFlags.has("-design") { return .design() }
        #endif
        return ScreenshotData.isActive ? .screenshots() : .live()
    }
}
