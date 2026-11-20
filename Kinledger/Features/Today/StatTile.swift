import SwiftUI

struct StatTile: View {
    let label: String
    let value: String
    let tone: Tone

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.title2.weight(.semibold))
                .foregroundStyle(tone.color)
                .minimumScaleFactor(0.7)
                .lineLimit(2)
            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Palette.textSecondary)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tone.soft, in: RoundedRectangle(cornerRadius: Metrics.tileRadius))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(value)")
    }
}
