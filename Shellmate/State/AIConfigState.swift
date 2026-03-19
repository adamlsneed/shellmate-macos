import Foundation
import Observation

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
    var provider: AIProvider = .anthropic
    var model: String = "claude-sonnet-4-20250514"
    var authMethod: AuthMethod = .apiKey
    var isConfigured: Bool = false

    /// Resolve API key: Keychain first, then environment variable.
    func resolveApiKey() -> String? {
        // Try Keychain first
        if let key = KeychainHelper.read(service: "com.shellmate.api", account: provider.rawValue), !key.isEmpty {
            return key
        }
        // Fall back to environment variable
        return ProcessInfo.processInfo.environment[provider.envKeyName]
    }
}
