import SwiftUI
import AVFoundation

struct RecordButton: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var isRecording = false
    @State private var animatePulse = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var recorder = AudioRecorder()

    var body: some View {
        Button {
            if !isRecording {
                startRecording()
            } else {
                stopRecording()
            }
        } label: {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 96, height: 96)
                    .shadow(color: .black.opacity(0.15), radius: 12, y: 6)

                Circle()
                    .stroke(AppTheme.ringGradient, lineWidth: 5)
                    .frame(width: 96, height: 96)

                Circle()
                    .fill(isRecording ? Color.red : AppTheme.playfulGradient)
                    .frame(width: isRecording ? 48 : 60, height: isRecording ? 48 : 60)
                    .clipShape(isRecording ? RoundedRectangle(cornerRadius: 12, style: .continuous) : Circle())
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isRecording ? "Stop recording" : "Start recording")
        .alert("Recording Error", isPresented: $showError, actions: {
            Button("OK", role: .cancel) {}
        }, message: {
            Text(errorMessage ?? "Unknown error")
        })
    }

    private func startRecording() {
        Task {
            do {
                try await recorder.start()
                Haptics.impact(.heavy)
                withAnimation(.easeInOut(duration: 0.25)) { isRecording = true }
                animatePulse = true
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                showError = true
                animatePulse = false
                isRecording = false
                Haptics.error()
            }
        }
    }

    private func stopRecording() {
        do {
            let result = try recorder.stop()
            Haptics.selection()
            withAnimation(.easeInOut(duration: 0.25)) { isRecording = false }
            animatePulse = false
            // Persist to CloudKit
            appModel.saveRecording(fileURL: result.fileURL, duration: result.duration)
            Haptics.success()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            showError = true
            animatePulse = false
            isRecording = false
            Haptics.error()
        }
    }
}

#Preview {
    RecordButton()
        .padding()
        .background(Color(.systemGroupedBackground))
}
