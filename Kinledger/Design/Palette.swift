import SwiftUI
import UIKit

/// Kinledger colors. Rationale and contrast checks: docs/design.md.
///
/// One color per quantity, the same in the app and in the report siblings see:
/// time = teal, money = ochre, visits = indigo. Red is for input errors only.
enum Palette {
    static let background = Color(light: 0xF7F5F0, dark: 0x121816)
    static let card = Color(light: 0xFFFFFF, dark: 0x1B2320)
    static let border = Color(light: 0xE4E1D8, dark: 0x2C3632)
    static let divider = Color(light: 0xECE9E1, dark: 0x2C3632)
    static let text = Color(light: 0x18211E, dark: 0xECF1EE)
    static let textSecondary = Color(light: 0x4F5A55, dark: 0xA9B4AF)

    static let time = Color(light: 0x0B6E66, dark: 0x5CC2B5)
    static let timeSoft = Color(light: 0xDDEFEA, dark: 0x173A36)
    static let onTime = Color(light: 0xFFFFFF, dark: 0x121816)

    static let money = Color(light: 0xA24E05, dark: 0xF0A55A)
    static let moneySoft = Color(light: 0xFCEBD3, dark: 0x3A2A17)
    static let moneyInk = Color(light: 0x6B3307, dark: 0xF7C99A)

    static let visits = Color(light: 0x4353A6, dark: 0x9AA6F0)
    static let visitsSoft = Color(light: 0xE5E8F7, dark: 0x1E2540)

    static let error = Color(light: 0xB3261E, dark: 0xF2B8B5)
    static let neutralSoft = Color(light: 0xECE9E1, dark: 0x2C3632)
}

/// The three quantities the app counts, each with its own color pair.
enum Tone {
    case time, money, visits

    var color: Color {
        switch self {
        case .time: Palette.time
        case .money: Palette.money
        case .visits: Palette.visits
        }
    }

    var soft: Color {
        switch self {
        case .time: Palette.timeSoft
        case .money: Palette.moneySoft
        case .visits: Palette.visitsSoft
        }
    }
}

/// Sizes for a 40–65 audience. Text styles follow Dynamic Type, so larger system
/// text settings make everything bigger.
enum Metrics {
    static let cardRadius: CGFloat = 20
    static let tileRadius: CGFloat = 12
    /// Touch targets: 44 minimum, primary actions 56.
    static let minTouch: CGFloat = 44
    static let primaryTouch: CGFloat = 56
    static let maxContentWidth: CGFloat = 640
}

extension Color {
    /// A color that switches with light and dark mode. Hex as 0xRRGGBB.
    init(light: UInt32, dark: UInt32) {
        let lightColor = UIColor(rgb: light)
        let darkColor = UIColor(rgb: dark)
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? darkColor : lightColor
        })
    }
}

extension UIColor {
    convenience init(rgb: UInt32) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}
