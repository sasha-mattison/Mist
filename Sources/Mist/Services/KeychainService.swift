import Foundation
import Security

/// Stores the user's personal Steam Web API key in the macOS Keychain.
enum KeychainService {
    private static let service = "dev.sasha.Mist.webapikey"
    /// Pre-rename service id (the app used to be "SteamClient"); read as a
    /// fallback and migrated forward so existing users stay signed in.
    private static let legacyService = "com.steamclient.webapikey"
    private static let account = "steamWebAPIKey"

    enum KeychainError: Error, LocalizedError {
        case unhandled(OSStatus)

        var errorDescription: String? {
            switch self {
            case .unhandled(let status):
                return "Keychain error (status \(status))"
            }
        }
    }

    static func saveAPIKey(_ key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)

        var attributes = query
        attributes[kSecValueData as String] = Data(key.utf8)
        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unhandled(status)
        }
    }

    static func loadAPIKey() -> String? {
        if let key = loadAPIKey(service: service) {
            return key
        }
        // Migrate a key saved under the old app name to the new service id.
        guard let legacyKey = loadAPIKey(service: legacyService) else { return nil }
        try? saveAPIKey(legacyKey)
        return legacyKey
    }

    private static func loadAPIKey(service: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func deleteAPIKey() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
