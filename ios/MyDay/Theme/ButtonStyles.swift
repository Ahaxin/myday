import SwiftUI

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .foregroundStyle(.white)
            .background(AppTheme.playfulGradient)
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .stroke(AppTheme.ocean.opacity(0.6), lineWidth: 2)
                    .background(Capsule().fill(Color(.systemBackground)))
            )
            .foregroundStyle(AppTheme.ocean)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

