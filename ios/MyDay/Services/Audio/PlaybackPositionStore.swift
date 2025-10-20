import Foundation

enum PlaybackPositionStore {
    private static let prefix = "playbackPosition."

    static func key(for id: UUID) -> String { prefix + id.uuidString }

    static func save(position: TimeInterval, for id: UUID) {
        UserDefaults.standard.set(position, forKey: key(for: id))
    }

    static func load(for id: UUID) -> TimeInterval? {
        let key = key(for: id)
        if UserDefaults.standard.object(forKey: key) == nil { return nil }
        return UserDefaults.standard.double(forKey: key)
    }

    static func clear(for id: UUID) {
        UserDefaults.standard.removeObject(forKey: key(for: id))
    }
}

