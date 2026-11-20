import SwiftUI

@main
struct KinledgerApp: App {
    @State private var model = KinledgerApp.makeModel()
    @State private var pro = ProStore(unlocked: DesignFlags.pro)
    @Environment(\.scenePhase) private var scenePhase

    init() {
        if !ScreenshotData.isActive { Diagnostics.shared.start() }
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
                .task { pro.start() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { model.cloud.syncSoon(delay: .zero) }
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
