import SwiftUI

private struct CareProfileKey: EnvironmentKey {
    static let defaultValue = CareProfile.placeholder
}

extension EnvironmentValues {
    /// Who is cared for, and which currency to show. Set once at the root.
    var careProfile: CareProfile {
        get { self[CareProfileKey.self] }
        set { self[CareProfileKey.self] = newValue }
    }
}
