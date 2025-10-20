import Foundation
import CloudKit

public enum LocalExportService {
    /// Builds a folder with audio and transcript files for all entries and returns the folder URL.
    public static func exportAllEntries() async throws -> URL {
        let ck = CloudKitService.shared
        let records = try await ck.fetchEntryRecords()
        let exportDir = try makeExportDirectory()

        for record in records {
            guard let createdAt = record["updatedAt"] as? Date ?? record["createdAt"] as? Date else { continue }
            let base = filenameDateFormatter.string(from: createdAt)

            if let transcript = record["transcriptClean"] as? String, !transcript.isEmpty {
                let txtURL = exportDir.appendingPathComponent("\(base).txt")
                try transcript.data(using: .utf8)?.write(to: txtURL)
            }

            if let asset = record["audio"] as? CKAsset, let fileURL = asset.fileURL {
                let m4aURL = exportDir.appendingPathComponent("\(base).m4a")
                try copyReplacingIfExists(from: fileURL, to: m4aURL)
            }
        }

        return exportDir
    }

    private static func makeExportDirectory() throws -> URL {
        let ts = compactDateFormatter.string(from: Date())
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("MyDayExport_\(ts)", isDirectory: true)
        if FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.removeItem(at: dir)
        }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static func copyReplacingIfExists(from: URL, to: URL) throws {
        if FileManager.default.fileExists(atPath: to.path) {
            try FileManager.default.removeItem(at: to)
        }
        try FileManager.default.copyItem(at: from, to: to)
    }

    private static let filenameDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return df
    }()

    private static let compactDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd_HHmmss"
        return df
    }()
}

