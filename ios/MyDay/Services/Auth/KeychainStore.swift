import Foundation
import Security

public enum KeychainStoreError: Error {
    case unexpectedStatus(OSStatus)
}

public protocol KeychainStoreProtocol: Sendable {
    func set(_ value: Data, for key: String) throws
    func data(for key: String) throws -> Data?
    func removeValue(for key: String) throws
}

/// Minimal Keychain wrapper used to persist authentication tokens.
public struct KeychainStore: KeychainStoreProtocol {
    private let service: String

    public init(service: String) {
        self.service = service
    }

    public func set(_ value: Data, for key: String) throws {
        var query = baseQuery(for: key)
        query[kSecValueData as String] = value as CFData

        let status = SecItemAdd(query as CFDictionary, nil)

        switch status {
        case errSecSuccess:
            return
        case errSecDuplicateItem:
            let attributesToUpdate = [kSecValueData as String: value as CFData]
            let updateStatus = SecItemUpdate(baseQuery(for: key) as CFDictionary, attributesToUpdate as CFDictionary)
            guard updateStatus == errSecSuccess else {
                throw KeychainStoreError.unexpectedStatus(updateStatus)
            }
        default:
            throw KeychainStoreError.unexpectedStatus(status)
        }
    }

    public func data(for key: String) throws -> Data? {
        var query = baseQuery(for: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        switch status {
        case errSecSuccess:
            guard let data = item as? Data else {
                throw KeychainStoreError.unexpectedStatus(errSecInternalComponent)
            }
            return data
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainStoreError.unexpectedStatus(status)
        }
    }

    public func removeValue(for key: String) throws {
        let status = SecItemDelete(baseQuery(for: key) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainStoreError.unexpectedStatus(status)
        }
    }

    private func baseQuery(for key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
    }
}
