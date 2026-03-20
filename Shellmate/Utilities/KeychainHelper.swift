import Foundation
import Security
import os

/// Wrapper around Security.framework for Keychain CRUD operations.
/// API keys and OAuth tokens are stored here -- never in UserDefaults or plain files.
enum KeychainHelper {
    private static let logger = Logger(subsystem: "com.shellmate.app", category: "keychain")

    // MARK: - Core Operations

    /// Save a value to the Keychain.
    @discardableResult
    static func save(service: String, account: String, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }

        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked,
        ]
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        if status != errSecSuccess {
            logger.error("Keychain save failed: \(status) for \(account)")
        }
        return status == errSecSuccess
    }

    /// Read a value from the Keychain.
    static func read(service: String, account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Delete a value from the Keychain.
    @discardableResult
    static func delete(service: String, account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    /// Check if a value exists in the Keychain without retrieving it.
    static func exists(service: String, account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: false,
        ]
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    // MARK: - API Key Convenience

    static let apiKeyService = "com.shellmate.api"

    /// Save an API key for a provider.
    @discardableResult
    static func saveApiKey(_ key: String, for provider: AIProvider) -> Bool {
        logger.info("Saving API key for \(provider.rawValue)")
        return save(service: apiKeyService, account: provider.rawValue, value: key)
    }

    /// Read an API key for a provider.
    static func readApiKey(for provider: AIProvider) -> String? {
        read(service: apiKeyService, account: provider.rawValue)
    }

    /// Delete an API key for a provider.
    @discardableResult
    static func deleteApiKey(for provider: AIProvider) -> Bool {
        logger.info("Deleting API key for \(provider.rawValue)")
        return delete(service: apiKeyService, account: provider.rawValue)
    }

    /// Delete all stored API keys and tokens for all providers.
    /// Call on app reset or uninstall cleanup.
    static func deleteAllKeys() {
        logger.info("Deleting all stored keys and tokens")
        for provider in AIProvider.allCases {
            deleteApiKey(for: provider)
            deleteOAuthToken(for: provider)
        }
    }

    // MARK: - OAuth Token Convenience

    static let oauthTokenService = "com.shellmate.oauth"

    /// Save an OAuth token with an optional expiry timestamp.
    @discardableResult
    static func saveOAuthToken(_ token: String, for provider: AIProvider, expiresAt: Date? = nil) -> Bool {
        logger.info("Saving OAuth token for \(provider.rawValue)")
        let tokenSaved = save(service: oauthTokenService, account: provider.rawValue, value: token)
        if let expiresAt {
            let expiryStr = String(expiresAt.timeIntervalSince1970)
            save(service: oauthTokenService, account: "\(provider.rawValue)-expiry", value: expiryStr)
        }
        return tokenSaved
    }

    /// Read an OAuth token, returning nil if expired.
    static func readOAuthToken(for provider: AIProvider) -> String? {
        if let expiryStr = read(service: oauthTokenService, account: "\(provider.rawValue)-expiry"),
           let expiryTimestamp = TimeInterval(expiryStr) {
            let expiryDate = Date(timeIntervalSince1970: expiryTimestamp)
            if expiryDate < Date() {
                logger.warning("OAuth token for \(provider.rawValue) has expired")
                delete(service: oauthTokenService, account: provider.rawValue)
                delete(service: oauthTokenService, account: "\(provider.rawValue)-expiry")
                return nil
            }
        }
        return read(service: oauthTokenService, account: provider.rawValue)
    }

    /// Check if an OAuth token exists and is not expired.
    static func hasValidOAuthToken(for provider: AIProvider) -> Bool {
        readOAuthToken(for: provider) != nil
    }

    /// Delete an OAuth token and its expiry.
    @discardableResult
    static func deleteOAuthToken(for provider: AIProvider) -> Bool {
        logger.info("Deleting OAuth token for \(provider.rawValue)")
        delete(service: oauthTokenService, account: "\(provider.rawValue)-expiry")
        return delete(service: oauthTokenService, account: provider.rawValue)
    }
}
