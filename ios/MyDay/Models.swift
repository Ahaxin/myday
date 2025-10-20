import Foundation
import SwiftUI

struct DayEntry: Identifiable, Hashable {
    enum Status: String, CaseIterable, Identifiable {
        case recording
        case processing
        case transcribed
        case error

        var id: String { rawValue }

        var description: String {
            switch self {
            case .recording:
                return "Recording"
            case .processing:
                return "Processing"
            case .transcribed:
                return "Transcribed"
            case .error:
                return "Error"
            }
        }

        var iconName: String {
            switch self {
            case .recording:
                return "waveform"
            case .processing:
                return "gearshape"
            case .transcribed:
                return "text.alignleft"
            case .error:
                return "exclamationmark.triangle"
            }
        }

        var color: Color {
            switch self {
            case .recording:
                return .accentColor
            case .processing:
                return .blue
            case .transcribed:
                return .green
            case .error:
                return .red
            }
        }
    }

    let id: UUID
    let createdAt: Date
    let duration: TimeInterval
    let sizeBytes: Int
    let status: Status
    let title: String
    let transcriptPreview: String

    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02dm %02ds", minutes, seconds)
    }

    var formattedDate: String {
        Self.dateFormatter.string(from: createdAt)
    }

    var formattedSize: String {
        Self.byteCountFormatter.string(fromByteCount: Int64(sizeBytes))
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private static let byteCountFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter
    }()
}

struct ExportRequest: Identifiable, Hashable {
    enum Status: String, CaseIterable, Identifiable {
        case pending
        case running
        case complete
        case failed

        var id: String { rawValue }

        var description: String {
            switch self {
            case .pending:
                return "Pending"
            case .running:
                return "Generating"
            case .complete:
                return "Ready"
            case .failed:
                return "Failed"
            }
        }

        var iconName: String {
            switch self {
            case .pending:
                return "tray"
            case .running:
                return "arrow.triangle.2.circlepath"
            case .complete:
                return "checkmark.circle"
            case .failed:
                return "xmark.octagon"
            }
        }

        var color: Color {
            switch self {
            case .pending:
                return .gray
            case .running:
                return .blue
            case .complete:
                return .green
            case .failed:
                return .red
            }
        }
    }

    let id: UUID
    let createdAt: Date
    let status: Status
    let rangeDescription: String
    let destinationEmail: String
    let downloadURL: URL?

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }
}
