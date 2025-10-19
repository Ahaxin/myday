import SwiftUI

struct EntryListView: View {
    let entries: [DayEntry]

    var body: some View {
        Group {
            if entries.isEmpty {
                ContentUnavailableView(
                    "No recordings yet",
                    systemImage: "waveform.slash",
                    description: Text("Tap the microphone to capture your first thought.")
                )
            } else {
                List {
                    Section {
                        EntrySummaryView(entries: entries)
                            .listRowInsets(.init(top: 12, leading: 0, bottom: 12, trailing: 0))
                            .listRowBackground(Color.clear)
                    }

                    Section("Recent") {
                        ForEach(entries) { entry in
                            NavigationLink(value: entry) {
                                EntryRowView(entry: entry)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .background(Color(.systemGroupedBackground))
                .navigationDestination(for: DayEntry.self) { entry in
                    EntryDetailView(entry: entry)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            RecordButton()
                .padding(.horizontal)
                .padding(.bottom)
        }
        .background(Color(.systemGroupedBackground))
    }
}

struct EntryRowView: View {
    let entry: DayEntry

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(entry.status.color)
                    .frame(width: 44, height: 44)
                    .opacity(0.15)
                Image(systemName: entry.status.iconName)
                    .font(.title3)
                    .foregroundStyle(entry.status.color)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title)
                    .font(.headline)
                Text(entry.formattedDate)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(entry.transcriptPreview)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Label(entry.status.description, systemImage: entry.status.iconName)
                    .font(.caption)
                    .labelStyle(.iconOnly)
                    .foregroundStyle(entry.status.color)
                Text(entry.formattedDuration)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(entry.formattedSize)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    NavigationStack {
        EntryListView(entries: PreviewData.sampleEntries)
            .navigationTitle("My Day")
    }
}
