import SwiftUI

/// Rounded square with a category symbol, tinted by quantity, as in the mockups.
struct IconTile: View {
    let symbol: String
    let tone: Tone
    var size: CGFloat = 40

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.45, weight: .medium))
            .foregroundStyle(tone.color)
            .frame(width: size, height: size)
            .background(tone.soft, in: RoundedRectangle(cornerRadius: Metrics.tileRadius))
            .accessibilityHidden(true)
    }
}

/// Dark pill at the bottom of the screen with one action, used for Undo.
struct Toast: View {
    let text: String
    let action: String
    let onAction: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "trash")
            Text(text).frame(maxWidth: .infinity, alignment: .leading)
            Button(action, action: onAction)
                .fontWeight(.bold)
                .foregroundStyle(Color(light: 0x8FE0D4, dark: 0x0B6E66))
        }
        .font(.subheadline)
        .foregroundStyle(Palette.background)
        .padding(16)
        .background(Palette.text, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
