import SwiftUI

/// "hi, Questioner!" speech bubble shown above the character on first launch.
struct OnboardingBubbleView: View {
    @Environment(\.theme) private var theme

    var body: some View {
        Text("hi, Questioner!")
            .font(theme.monoFont)
            .foregroundStyle(theme.foreground)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(theme.background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(theme.foreground.opacity(0.15), lineWidth: 0.5)
            )
    }
}
