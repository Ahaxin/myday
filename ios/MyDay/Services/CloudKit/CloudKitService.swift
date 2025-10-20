import Foundation
import CloudKit

/// CloudKit-backed storage for MyDay entries with audio stored as CKAsset.
public final class CloudKitService {
    public static let shared = CloudKitService()

    private let container: CKContainer
    private let database: CKDatabase

    // Configure your container identifier in the app target capabilities (iCloud > CloudKit)
    // and Info.plist. Using default container here for simplicity.
    public init(container: CKContainer = .default()) {
        self.container = container
        self.database = container.privateCloudDatabase
    }

    // MARK: - Public API

    /// Saves a new entry with the provided local audio file. The file is uploaded as a CKAsset.
    @discardableResult
    public func saveEntry(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        duration: TimeInterval,
        audioFileURL: URL,
        transcript: String? = nil
    ) async throws -> CKRecord.ID {
        let record = CKRecord(recordType: RecordType.entry)
        record[Field.id] = id.uuidString as CKRecordValue
        record[Field.createdAt] = createdAt as CKRecordValue
        record[Field.duration] = duration as CKRecordValue
        record[Field.sizeBytes] = (try? fileSize(at: audioFileURL)) as CKRecordValue?
        record[Field.status] = "uploaded" as CKRecordValue
        record[Field.updatedAt] = Date() as CKRecordValue
        if let transcript { record[Field.transcriptClean] = transcript as CKRecordValue }
        record[Field.audio] = CKAsset(fileURL: audioFileURL)

        let saved = try await save(record: record)
        return saved.recordID
    }

    /// Fetches entries, optionally filtered by last updated date.
    public func fetchEntries(updatedSince: Date? = nil) async throws -> [DayEntry] {
        let predicate: NSPredicate
        if let since = updatedSince {
            predicate = NSPredicate(format: "%K > %@", Field.updatedAt, since as NSDate)
        } else {
            predicate = NSPredicate(value: true)
        }
        let query = CKQuery(recordType: RecordType.entry, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: Field.createdAt, ascending: false)]

        var all: [CKRecord] = []
        var cursor: CKQueryOperation.Cursor?

        repeat {
            let page: QueryPage = try await performQuery(query: query, cursor: cursor)
            all.append(contentsOf: page.records)
            cursor = page.cursor
        } while cursor != nil

        return all.compactMap { Self.dayEntry(from: $0) }
    }

    /// Fetch CKRecords for export, including `audio` and transcript fields.
    public func fetchEntryRecords(updatedSince: Date? = nil) async throws -> [CKRecord] {
        let predicate: NSPredicate
        if let since = updatedSince {
            predicate = NSPredicate(format: "%K > %@", Field.updatedAt, since as NSDate)
        } else {
            predicate = NSPredicate(value: true)
        }
        let query = CKQuery(recordType: RecordType.entry, predicate: predicate)
        let desiredKeys = [Field.id, Field.createdAt, Field.duration, Field.sizeBytes, Field.status, Field.updatedAt, Field.transcriptClean, Field.audio]

        var all: [CKRecord] = []
        var cursor: CKQueryOperation.Cursor?
        repeat {
            let page: QueryPage = try await performQuery(query: query, cursor: cursor, desiredKeys: desiredKeys)
            all.append(contentsOf: page.records)
            cursor = page.cursor
        } while cursor != nil
        return all
    }

    /// Returns the local file URL for the audio asset of an entry with the given id, if available.
    public func audioAssetURL(for entryID: UUID) async throws -> URL? {
        let predicate = NSPredicate(format: "%K == %@", Field.id, entryID.uuidString)
        let query = CKQuery(recordType: RecordType.entry, predicate: predicate)
        let page: QueryPage = try await performQuery(query: query, cursor: nil, desiredKeys: [Field.audio])
        guard let record = page.records.first,
              let asset = record[Field.audio] as? CKAsset,
              let url = asset.fileURL else { return nil }
        return url
    }

    // MARK: - Private helpers

    private struct RecordType {
        static let entry = "Entry"
    }

    private struct Field {
        static let id = "id"
        static let createdAt = "createdAt"
        static let duration = "duration"
        static let status = "status"
        static let sizeBytes = "sizeBytes"
        static let updatedAt = "updatedAt"
        static let transcriptRaw = "transcriptRaw"
        static let transcriptClean = "transcriptClean"
        static let audio = "audio" // CKAsset
    }

    private func fileSize(at url: URL) throws -> NSNumber {
        let values = try url.resourceValues(forKeys: [.fileSizeKey])
        return NSNumber(value: values.fileSize ?? 0)
    }

    private func save(record: CKRecord) async throws -> CKRecord {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CKRecord, Error>) in
            database.save(record) { saved, error in
                if let error { continuation.resume(throwing: error) }
                else if let saved { continuation.resume(returning: saved) }
                else { continuation.resume(throwing: CKError(.unknownItem)) }
            }
        }
    }

    private struct QueryPage { let records: [CKRecord]; let cursor: CKQueryOperation.Cursor? }

    private func performQuery(query: CKQuery, cursor: CKQueryOperation.Cursor?, desiredKeys: [String]? = nil) async throws -> QueryPage {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<QueryPage, Error>) in
            let op: CKQueryOperation
            if let cursor { op = CKQueryOperation(cursor: cursor) } else { op = CKQueryOperation(query: query) }
            op.desiredKeys = desiredKeys

            var fetched: [CKRecord] = []
            op.recordFetchedBlock = { record in fetched.append(record) }
            op.queryCompletionBlock = { newCursor, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: QueryPage(records: fetched, cursor: newCursor)) }
            }
            op.qualityOfService = .userInitiated
            self.database.add(op)
        }
    }

    private static func dayEntry(from record: CKRecord) -> DayEntry? {
        guard
            let idString = record[Field.id] as? String,
            let id = UUID(uuidString: idString),
            let createdAt = record[Field.createdAt] as? Date
        else { return nil }

        let duration = (record[Field.duration] as? Double) ?? 0
        let sizeBytes = (record[Field.sizeBytes] as? NSNumber)?.intValue ?? 0
        let statusRaw = (record[Field.status] as? String) ?? "uploaded"
        let transcriptClean = record[Field.transcriptClean] as? String
        let transcriptPreview = transcriptClean.map { String($0.prefix(160)) } ?? ""
        let title = DateFormatter.localizedString(from: createdAt, dateStyle: .medium, timeStyle: .short)

        return DayEntry(
            id: id,
            createdAt: createdAt,
            duration: duration,
            sizeBytes: sizeBytes,
            status: Self.mapStatus(statusRaw),
            title: title,
            transcriptPreview: transcriptPreview
        )
    }

    private static func mapStatus(_ raw: String) -> DayEntry.Status {
        switch raw.lowercased() {
        case "transcribed": return .transcribed
        case "failed": return .error
        case "uploaded", "uploading", "processing": return .processing
        default: return .processing
        }
    }
}
