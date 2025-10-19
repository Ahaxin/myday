import Foundation

enum PreviewData {
    static let sampleEntries: [DayEntry] = [
        DayEntry(
            id: UUID(),
            createdAt: Calendar.current.date(byAdding: .minute, value: -5, to: Date()) ?? Date(),
            duration: 240,
            sizeBytes: 5_242_880,
            status: .transcribed,
            title: "Morning Reflection",
            transcriptPreview: "Grateful for the quiet start to the day and the chance to reset."
        ),
        DayEntry(
            id: UUID(),
            createdAt: Calendar.current.date(byAdding: .hour, value: -2, to: Date()) ?? Date(),
            duration: 95,
            sizeBytes: 2_097_152,
            status: .processing,
            title: "Lunchtime Walk",
            transcriptPreview: "Talked through project goals while enjoying the sun."
        ),
        DayEntry(
            id: UUID(),
            createdAt: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date(),
            duration: 360,
            sizeBytes: 7_340_032,
            status: .error,
            title: "Evening Ideas",
            transcriptPreview: "Need to re-record thoughts on the new onboarding flow."
        ),
    ]

    static let sampleExports: [ExportRequest] = [
        ExportRequest(
            id: UUID(),
            createdAt: Calendar.current.date(byAdding: .hour, value: -3, to: Date()) ?? Date(),
            status: .complete,
            rangeDescription: "This Week",
            destinationEmail: "me@example.com",
            downloadURL: URL(string: "https://cdn.example.com/exports/week.zip")
        ),
        ExportRequest(
            id: UUID(),
            createdAt: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date(),
            status: .running,
            rangeDescription: "Yesterday",
            destinationEmail: "ops@example.com",
            downloadURL: nil
        ),
        ExportRequest(
            id: UUID(),
            createdAt: Calendar.current.date(byAdding: .day, value: -2, to: Date()) ?? Date(),
            status: .failed,
            rangeDescription: "Last Week",
            destinationEmail: "archive@example.com",
            downloadURL: nil
        ),
    ]
}
