import Foundation
import Observation
import os

/// AI provider selection
enum AIProvider: String, Codable, CaseIterable, Sendable {
    case anthropic
    case openai

    var displayName: String {
        switch self {
        case .anthropic: "Anthropic (Claude)"
        case .openai: "OpenAI (GPT)"
        }
    }

    var defaultModel: String {
        switch self {
        case .anthropic: "claude-sonnet-4-20250514"
        case .openai: "gpt-4o"
        }
    }

    var envKeyName: String {
        switch self {
        case .anthropic: "ANTHROPIC_API_KEY"
        case .openai: "OPENAI_API_KEY"
        }
    }
}

/// Authentication method for AI providers
enum AuthMethod: String, Codable, Sendable {
    case apiKey
    case oauthToken
    case envKey
}

/// Detect provider from model name prefix (nonisolated utility).
func detectProvider(model: String) -> AIProvider {
    let lower = model.lowercased()
    if lower.hasPrefix("claude") || lower.hasPrefix("anthropic") {
        return .anthropic
    } else if lower.hasPrefix("gpt") || lower.hasPrefix("o1") || lower.hasPrefix("o3") || lower.hasPrefix("o4") {
        return .openai
    }
    return .anthropic
}

/// Normalize model string by stripping provider prefix if present.
func normalizeModel(_ model: String) -> String {
    let prefixes = ["anthropic/", "openai/"]
    for prefix in prefixes {
        if model.lowercased().hasPrefix(prefix) {
            return String(model.dropFirst(prefix.count))
        }
    }
    return model
}

/// Check if an OAuth token (sk-ant-oat prefix)
func isOAuthToken(_ key: String) -> Bool {
    key.hasPrefix("sk-ant-oat")
}

/// Observable state for AI provider configuration.
@Observable
@MainActor
final class AIConfigState {
    private static let logger = Logger(subsystem: "com.shellmate.app", category: "ai-config")

    var provider: AIProvider = .anthropic
    var model: String = "claude-sonnet-4-20250514"
    var authMethod: AuthMethod = .apiKey
    var isConfigured: Bool = false
    var isValidatingKey: Bool = false
    var keyValidationError: String?

    /// Resolve API key using the priority chain:
    /// 1. OAuth token (if not expired)
    /// 2. Keychain API key
    /// 3. Environment variable
    /// 4. CLAUDE_CODE_OAUTH_TOKEN env var (Anthropic only)
    func resolveApiKey() -> String? {
        if let token = KeychainHelper.readOAuthToken(for: provider) {
            return token
        }
        if let key = KeychainHelper.readApiKey(for: provider), !key.isEmpty {
            return key
        }
        if let key = ProcessInfo.processInfo.environment[provider.envKeyName], !key.isEmpty {
            return key
        }
        if provider == .anthropic {
            if let token = ProcessInfo.processInfo.environment["CLAUDE_CODE_OAUTH_TOKEN"], !token.isEmpty {
                return token
            }
        }
        return nil
    }

    /// Validate the current API key by making a test call.
    func validateCurrentKey() async {
        guard let apiKey = resolveApiKey() else {
            keyValidationError = "No API key found"
            isConfigured = false
            return
        }
        isValidatingKey = true
        keyValidationError = nil

        let result = await AIRouter.validateApiKey(provider: provider, apiKey: apiKey)

        isValidatingKey = false
        switch result {
        case .success:
            isConfigured = true
            keyValidationError = nil
            Self.logger.info("API key validated for \(self.provider.rawValue)")
        case .failure(let error):
            isConfigured = false
            keyValidationError = error.localizedDescription
            Self.logger.warning("API key validation failed: \(error.localizedDescription)")
        }
    }

    /// Save an API key and validate it.
    func saveAndValidateKey(_ key: String) async {
        KeychainHelper.saveApiKey(key, for: provider)
        if isOAuthToken(key) {
            authMethod = .oauthToken
        } else {
            authMethod = .apiKey
        }
        await validateCurrentKey()
    }
}
