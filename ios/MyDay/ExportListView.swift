import SwiftUI

struct ExportListView: View {
    let exports: [ExportRequest]

    var body: some View {
        List {
            Section {
                Button(action: {}) {
                    Label("Create Export", systemImage: "plus.circle.fill")
                        .font(.headline)
                }
            }

            if exports.isEmpty {
                Section {
                    ContentUnavailableView(
                        "No exports",
                        systemImage: "tray",
                        description: Text("Generate a ZIP archive to receive your recordings via email.")
                    )
                }
            } else {
                Section("History") {
                    ForEach(exports) { export in
                        ExportRowView(export: export)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
    }
}

struct ExportRowView: View {
    let export: ExportRequest

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(export.status.description, systemImage: export.status.iconName)
                    .font(.subheadline)
                    .foregroundStyle(export.status.color)
                Spacer()
                Text(export.formattedDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(export.rangeDescription)
                    .font(.headline)
                Text(export.destinationEmail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let downloadURL = export.downloadURL {
                Link(destination: downloadURL) {
                    Label("Download", systemImage: "arrow.down.circle")
                        .font(.callout)
                }
            } else {
                Text(export.status == .failed ? "Export failed" : "We will email you when it's ready")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        ExportListView(exports: PreviewData.sampleExports)
            .navigationTitle("Exports")
    }
}
