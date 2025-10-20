import SwiftUI

struct EntrySummaryView: View {
    let entries: [DayEntry]

    private var summaryStats: Summary {
        entries.reduce(into: Summary()) { partial, entry in
            partial.totalDuration += entry.duration
            if entry.status == .transcribed {
                partial.completedCount += 1
            }
            if partial.latestEntry == nil || entry.createdAt > partial.latestEntry!.createdAt {
                partial.latestEntry = entry
            }
        }
    }

    var body: some View {
        let summary = summaryStats

        VStack(alignment: .leading, spacing: 16) {
            Text("Today")
                .font(.headline)
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                SummaryStatView(title: "Minutes", value: "\(summary.totalMinutes)")
                SummaryStatView(title: "Completed", value: "\(summary.completedCount)")
                SummaryStatView(title: "Entries", value: "\(entries.count)")
            }

            if let latestEntry = summary.latestEntry {
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

private extension EntrySummaryView {
    struct Summary {
        var totalDuration: TimeInterval = 0
        var completedCount: Int = 0
        var latestEntry: DayEntry?

        var totalMinutes: Int {
            Int(totalDuration / 60)
        }
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
