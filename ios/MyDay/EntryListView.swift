import SwiftUI

struct EntryListView: View {
    let entries: [DayEntry]

    var body: some View {
        Group {
            if entries.isEmpty {
                PlayfulEmptyState(
                    title: "No recordings yet",
                    message: "Tap the colorful mic below to start your first story!",
                    symbolName: "waveform"
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
            VStack(spacing: 8) {
                RecordButton()
                Text(isChildFriendlyHint)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
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
                    .fill(AppTheme.playfulGradient)
                    .frame(width: 56, height: 56)
                    .opacity(0.25)
                Image(systemName: entry.status.iconName)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(entry.status.color, .white)
                    .font(.system(size: 22, weight: .semibold))
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
                Image(systemName: entry.status.iconName)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(entry.status.color, .white)
                    .font(.system(size: 18, weight: .semibold))
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

private var isChildFriendlyHint: String { "Tap to record a message" }

#Preview {
    NavigationStack {
        EntryListView(entries: PreviewData.sampleEntries)
            .navigationTitle("My Day")
    }
}
