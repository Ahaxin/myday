import SwiftUI

struct PlayfulEmptyState: View {
    var title: String
    var message: String
    var symbolName: String

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                // Decorative bubbles
                Circle()
                    .fill(AppTheme.playfulGradient)
                    .frame(width: 160, height: 160)
                    .opacity(0.25)
                    .offset(x: -10, y: -6)

                Circle()
                    .fill(AppTheme.playfulGradient)
                    .frame(width: 120, height: 120)
                    .opacity(0.20)
                    .offset(x: 22, y: 18)

                Circle()
                    .stroke(AppTheme.ringGradient, lineWidth: 6)
                    .frame(width: 180, height: 180)
                    .opacity(0.35)

                // Big symbol
                Image(systemName: symbolName)
                    .font(.system(size: 72, weight: .bold))
                    .foregroundStyle(AppTheme.playfulGradient)
                    .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
            }
            .padding(.bottom, 4)

            Text(title)
                .font(.title2).bold()
                .multilineTextAlignment(.center)

            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
    }
}

