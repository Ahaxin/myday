import SwiftUI

struct RecordButton: View {
    @State private var isRecording = false
    @State private var animatePulse = false

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                isRecording.toggle()
            }
            if isRecording {
                animatePulse = true
            } else {
                animatePulse = false
            }
        } label: {
            ZStack {
                Circle()
                    .fill(Color(.systemBackground))
                    .frame(width: 86, height: 86)
                    .shadow(radius: 12)

                Circle()
                    .strokeBorder(Color.accentColor.opacity(0.4), lineWidth: 4)
                    .frame(width: 86, height: 86)
                    .overlay(
                        Circle()
                            .fill(isRecording ? Color.red : Color.accentColor)
                            .frame(width: isRecording ? 44 : 54, height: isRecording ? 44 : 54)
                            .clipShape(isRecording ? RoundedRectangle(cornerRadius: 12, style: .continuous) : Circle())
                    )
                    .scaleEffect(animatePulse ? 1.05 : 1)
                    .animation(
                        animatePulse
                            ? .easeInOut(duration: 0.9).repeatForever(autoreverses: true)
                            : .default,
                        value: animatePulse
                    )
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isRecording ? "Stop recording" : "Start recording")
    }
}

#Preview {
    RecordButton()
        .padding()
        .background(Color(.systemGroupedBackground))
}
