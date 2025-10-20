import Foundation
import CloudKit

@MainActor
final class AppModel: ObservableObject {
    @Published var entries: [DayEntry]
    @Published var exports: [ExportRequest]

    init(entries: [DayEntry] = PreviewData.sampleEntries, exports: [ExportRequest] = PreviewData.sampleExports) {
        self.entries = entries
        self.exports = exports
        // Initial iCloud refresh on launch
        refresh()
    }

    func refresh() {
        Task {
            let fetched: [DayEntry]
            do {
                fetched = try await CloudKitService.shared.fetchEntries()
            } catch {
                // Fall back to previews on error so UI remains usable in dev
                fetched = PreviewData.sampleEntries
            }

            await MainActor.run {
                self.entries = fetched
                // Exports are not server-driven in iCloud-only mode; show empty for now
                self.exports = []
            }
        }
    }

    /// Saves a finished local recording to iCloud and refreshes entries.
    func saveRecording(fileURL: URL, duration: TimeInterval, transcript: String? = nil) {
        Task {
            do {
                _ = try await CloudKitService.shared.saveEntry(duration: duration, audioFileURL: fileURL, transcript: transcript)
                let fetched = try await CloudKitService.shared.fetchEntries()

                await MainActor.run {
                    self.entries = fetched
                }

                // Remove temporary file after successful save
                try? FileManager.default.removeItem(at: fileURL)
            } catch {
                // Optionally surface error to user
            }
        }
    }
}
