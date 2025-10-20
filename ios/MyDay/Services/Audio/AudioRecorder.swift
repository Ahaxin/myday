import Foundation
import AVFoundation

enum AudioRecorderError: Error, LocalizedError {
    case microphonePermissionDenied
    case failedToStart
    case notRecording

    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return "Microphone access is required to record."
        case .failedToStart:
            return "Failed to start recording."
        case .notRecording:
            return "No active recording."
        }
    }
}

final class AudioRecorder: NSObject, AVAudioRecorderDelegate {
    private var recorder: AVAudioRecorder?
    private var startTime: Date?

    func start() async throws {
        let session = AVAudioSession.sharedInstance()

        // Request permission if needed
        let granted = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            session.requestRecordPermission { allowed in continuation.resume(returning: allowed) }
        }
        guard granted else { throw AudioRecorderError.microphonePermissionDenied }

        try session.setCategory(.record, mode: .default, options: [])
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let fileURL = Self.makeOutputURL()
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        recorder = try AVAudioRecorder(url: fileURL, settings: settings)
        recorder?.delegate = self
        recorder?.isMeteringEnabled = false
        guard recorder?.record() == true else { throw AudioRecorderError.failedToStart }
        startTime = Date()
    }

    func stop() throws -> (fileURL: URL, duration: TimeInterval) {
        guard let recorder, let start = startTime else { throw AudioRecorderError.notRecording }
        recorder.stop()
        self.recorder = nil
        let duration = Date().timeIntervalSince(start)
        // Deactivate to return audio to system/other apps
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        return (recorder.url, max(0, duration))
    }

    private static func makeOutputURL() -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let name = "MyDay_\(formatter.string(from: Date())).m4a"
        return FileManager.default.temporaryDirectory.appendingPathComponent(name)
    }
}
