import SwiftUI

struct LargeTitleView: View {
    var title: String
    var symbolName: String = "sparkles"

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbolName)
                .font(.system(size: 28, weight: .bold))
            Text(title)
                .font(.system(size: 34, weight: .black, design: .rounded))
        }
        .foregroundStyle(AppTheme.playfulGradient)
        .minimumScaleFactor(0.8)
        .lineLimit(1)
    }
}

