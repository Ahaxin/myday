import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published var entries: [DayEntry]
    @Published var exports: [ExportRequest]

    init(entries: [DayEntry] = PreviewData.sampleEntries, exports: [ExportRequest] = PreviewData.sampleExports) {
        self.entries = entries
        self.exports = exports
    }

    func refresh() {
        entries = PreviewData.sampleEntries
        exports = PreviewData.sampleExports
    }
}
