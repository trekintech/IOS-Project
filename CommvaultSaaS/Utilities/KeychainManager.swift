import Foundation
import Security

/// Securely stores and retrieves sensitive data using the iOS Keychain.
final class KeychainManager {
    static let shared = KeychainManager()
    private init() {}

    enum KeychainKey: String {
        case apiToken = "com.commvault.saas.apiToken"
        case refreshToken = "com.commvault.saas.refreshToken"
        case ringEndpoint = "com.commvault.saas.ringEndpoint"
        case username = "com.commvault.saas.username"
    }

    func save(_ data: String, for key: KeychainKey) throws {
        guard let data = data.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }

        // Delete existing item first
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    func retrieve(for key: KeychainKey) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }

    func delete(for key: KeychainKey) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
        ]
        SecItemDelete(query as CFDictionary)
    }

    func deleteAll() {
        for key in [KeychainKey.apiToken, .refreshToken, .ringEndpoint, .username] {
            delete(for: key)
        }
    }
}

enum KeychainError: LocalizedError {
    case encodingFailed
    case saveFailed(OSStatus)
    case retrievalFailed

    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "Failed to encode data for keychain storage."
        case .saveFailed(let status):
            return "Keychain save failed with status: \(status)"
        case .retrievalFailed:
            return "Failed to retrieve data from keychain."
        }
    }
}
