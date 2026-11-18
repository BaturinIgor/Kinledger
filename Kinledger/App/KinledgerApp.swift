import SwiftUI

@main
struct KinledgerApp: App {
    @State private var model = AppModel.live()

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
                .environment(\.careProfile, model.careProfile)
                .tint(Palette.time)
        }
    }
}
