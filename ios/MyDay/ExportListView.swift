import SwiftUI
import UIKit

struct ExportListView: View {
    let exports: [ExportRequest]
    @State private var isExporting = false
    @State private var exportURL: URL?

    var body: some View {
        List {
            Section {
                Button(action: createExport) {
                    if isExporting {
                        ProgressView().progressViewStyle(.circular)
                    } else {
                        Label("Create Export", systemImage: "plus.circle.fill")
                            .font(.headline)
                    }
                }
                .disabled(isExporting)
                .buttonStyle(PrimaryButtonStyle())
            }

            if exports.isEmpty {
                Section {
                    PlayfulEmptyState(
                        title: "No exports yet",
                        message: "Create an export to share your stories with friends and family.",
                        symbolName: "tray.and.arrow.down"
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
        .sheet(isPresented: Binding<Bool>(
            get: { exportURL != nil },
            set: { if !$0 { exportURL = nil } }
        )) {
            if let url = exportURL {
                ShareView(activityItems: [url])
            }
        }
    }

    private func createExport() {
        isExporting = true
        Task {
            defer { isExporting = false }
            do {
                let url = try await LocalExportService.exportAllEntries()
                await MainActor.run { exportURL = url }
            } catch {
                // In a real app, surface error to user
            }
        }
    }
}

struct ExportRowView: View {
    let export: ExportRequest

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: export.status.iconName)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(export.status.color, .white)
                    .font(.system(size: 18, weight: .semibold))
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
                .buttonStyle(SecondaryButtonStyle())
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

// Minimal UIActivityViewController wrapper for sharing the export folder
struct ShareView: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
