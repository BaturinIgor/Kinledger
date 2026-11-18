import SwiftUI

@main
struct KinledgerApp: App {
    @State private var model = AppModel.live()
    @State private var pro = ProStore()

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
                .environment(\.careProfile, model.careProfile)
                .tint(Palette.time)
        }
    }
}
