import SwiftUI

struct EntryDetailView: View {
    let entry: DayEntry

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
                        .buttonStyle(.borderedProminent)

                        Button(action: {}) {
                            Label("Delete", systemImage: "trash")
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    }
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .background(Color(.systemGroupedBackground))
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
