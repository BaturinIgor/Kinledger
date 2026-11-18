import SwiftUI

@main
struct KinledgerApp: App {
    @State private var model = AppModel.live()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .tint(Palette.time)
        }
    }
}
