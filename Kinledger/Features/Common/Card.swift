import SwiftUI

/// White card on the paper background, as in the mockups.
struct Card<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: Metrics.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Metrics.cardRadius)
                .strokeBorder(Palette.border, lineWidth: 1)
        )
    }
}

/// Stand-in for screens that are designed but not built yet.
struct PlaceholderView: View {
    let title: String
    let message: String

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(message)
                    .font(.body)
                    .foregroundStyle(Palette.textSecondary)
                    .frame(maxWidth: Metrics.maxContentWidth, alignment: .leading)
                    .padding(16)
            }
            .frame(maxWidth: .infinity)
            .background(Palette.background)
            .navigationTitle(title)
        }
    }
}
