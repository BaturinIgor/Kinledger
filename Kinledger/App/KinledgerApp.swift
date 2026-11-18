import SwiftUI

@main
struct KinledgerApp: App {
    @State private var model = ScreenshotData.isActive ? AppModel.screenshots() : AppModel.live()
    @State private var pro = ProStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            Group {
                if model.profile == nil {
                    OnboardingView()
                } else {
                    RootView()
                }
            }
                .environment(model)
                .environment(pro)
                .task { pro.start() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { model.cloud.syncSoon(delay: .zero) }
                }
                .environment(\.careProfile, model.careProfile)
                .tint(Palette.time)
        }
    }
}
