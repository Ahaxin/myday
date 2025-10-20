import SwiftUI
import AVFoundation

struct EntryDetailView: View {
    let entry: DayEntry
    @StateObject private var audioPlayer = AudioPlayer()
    @State private var isLoadingAudio = false
    @State private var audioAvailable = false
    @State private var showToast = false
    @State private var toastMessage = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(entry.title)
                        .font(.largeTitle)
                        .bold()
                    Text(entry.formattedDate)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 16) {
                    StatusPill(status: entry.status)
                    Label(entry.formattedDuration, systemImage: "clock")
                        .font(.subheadline)
                    Label(entry.formattedSize, systemImage: "tray")
                        .font(.subheadline)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Playback")
                        .font(.title2)
                        .bold()
                    HStack(spacing: 16) {
                        Button(action: togglePlayback) {
                            if isLoadingAudio {
                                ProgressView()
                                    .progressViewStyle(.circular)
                            } else {
                                Label(audioPlayer.isPlaying ? "Pause" : "Play", systemImage: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(isLoadingAudio || !audioAvailable)
                        if !audioAvailable {
                            Text("Audio not available")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Scrubber
                    VStack(alignment: .leading) {
                        Slider(
                            value: Binding(
                                get: { audioPlayer.currentTime },
                                set: { newValue in audioPlayer.seek(to: newValue) }
                            ),
                            in: 0...max(audioPlayer.duration, 0.1)
                        )
                        .disabled(!audioAvailable)

                        HStack {
                            Text(formatTime(audioPlayer.currentTime))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(formatTime(audioPlayer.duration))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Transcript")
                        .font(.title2)
                        .bold()
                    Text(entry.transcriptPreview)
                        .font(.body)
                        .foregroundStyle(.primary)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Actions")
                        .font(.title2)
                        .bold()
                    HStack(spacing: 16) {
                        Button(action: {}) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(PrimaryButtonStyle())

                        Button(action: {}) {
                            Label("Delete", systemImage: "trash")
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    }
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .task { await loadAudioIfNeeded() }
        .onDisappear {
            // Persist last position and stop
            if audioPlayer.currentTime > 0 { PlaybackPositionStore.save(position: audioPlayer.currentTime, for: entry.id) }
            audioPlayer.stop()
        }
        .overlay(alignment: .bottom) {
            if showToast {
                ToastView(message: toastMessage)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 16)
            }
        }
    }

    private func loadAudioIfNeeded() async {
        guard !audioAvailable else { return }
        isLoadingAudio = true
        defer { isLoadingAudio = false }
        do {
            if let url = try await CloudKitService.shared.audioAssetURL(for: entry.id) {
                try audioPlayer.load(url: url)
                audioAvailable = true
                // Seek to last known position if any
                if let last = PlaybackPositionStore.load(for: entry.id), last > 0, last < audioPlayer.duration {
                    audioPlayer.seek(to: last)
                }
            } else {
                audioAvailable = false
                showErrorToast("Audio is not available for this entry.")
            }
        } catch {
            audioAvailable = false
            showErrorToast("Failed to load audio: \(error.localizedDescription)")
        }
    }

    private func togglePlayback() {
        if !audioAvailable { return }
        Haptics.selection()
        // If currently playing, store position before pausing
        if audioPlayer.isPlaying {
            PlaybackPositionStore.save(position: audioPlayer.currentTime, for: entry.id)
        }
        audioPlayer.togglePlay()
    }

    private func formatTime(_ t: TimeInterval) -> String {
        let total = Int(max(0, t))
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }

    private func showErrorToast(_ message: String) {
        toastMessage = message
        withAnimation { showToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation { showToast = false }
        }
    }
}

private struct ToastView: View {
    let message: String
    var body: some View {
        Text(message)
            .font(.footnote)
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.black.opacity(0.8))
            .clipShape(Capsule())
            .shadow(radius: 6)
    }
}

private struct StatusPill: View {
    let status: DayEntry.Status

    var body: some View {
        Label(status.description, systemImage: status.iconName)
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(status.color.opacity(0.15))
            .foregroundStyle(status.color)
            .clipShape(Capsule())
    }
}

#Preview {
    NavigationStack {
        EntryDetailView(entry: PreviewData.sampleEntries.first!)
    }
}
