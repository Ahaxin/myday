import SwiftUI

struct EntrySummaryView: View {
    let entries: [DayEntry]

    private var totalMinutes: Int {
        Int(entries.reduce(0) { $0 + $1.duration } / 60)
    }

    private var completedCount: Int {
        entries.filter { $0.status == .transcribed }.count
    }

    private var latestEntry: DayEntry? {
        entries.sorted { $0.createdAt > $1.createdAt }.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Today")
                .font(.headline)
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                SummaryStatView(title: "Minutes", value: "\(totalMinutes)")
                SummaryStatView(title: "Completed", value: "\(completedCount)")
                SummaryStatView(title: "Entries", value: "\(entries.count)")
            }

            if let latestEntry {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Latest note")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(latestEntry.title)
                        .font(.title3)
                        .bold()
                    Text(latestEntry.transcriptPreview)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.thinMaterial)
        )
    }
}

private struct SummaryStatView: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3)
                .bold()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    EntrySummaryView(entries: PreviewData.sampleEntries)
        .padding()
        .background(Color(.systemGroupedBackground))
}
