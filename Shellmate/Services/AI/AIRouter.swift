import Foundation
import os

/// Routes AI requests to the appropriate provider client.
struct AIRouter: Sendable {
    private static let logger = Logger(subsystem: "com.shellmate.app", category: "ai-router")

    /// Make an AI call using the configured provider.
    func call(
        messages: [[String: Any]],
        system: String? = nil,
        tools: [ToolDefinition] = [],
        provider: AIProvider,
        model: String,
        apiKey: String,
        maxTokens: Int = 4096,
        stream: Bool = false
    ) async throws -> AIResponse {
        switch provider {
        case .anthropic:
            return try await AnthropicClient.call(
                messages: messages, system: system, tools: tools,
                model: model, apiKey: apiKey, maxTokens: maxTokens
            )
        case .openai:
            return try await OpenAIClient.call(
                messages: messages, system: system, tools: tools,
                model: model, apiKey: apiKey, maxTokens: maxTokens
            )
        }
    }

    /// Stream an AI response using the configured provider.
    func stream(
        messages: [[String: Any]],
        system: String? = nil,
        tools: [ToolDefinition] = [],
        provider: AIProvider,
        model: String,
        apiKey: String,
        maxTokens: Int = 4096
    ) -> AsyncThrowingStream<StreamEvent, Error> {
        switch provider {
        case .anthropic:
            return AnthropicClient.stream(
                messages: messages, system: system, tools: tools,
                model: model, apiKey: apiKey, maxTokens: maxTokens
            )
        case .openai:
            return OpenAIClient.stream(
                messages: messages, system: system, tools: tools,
                model: model, apiKey: apiKey, maxTokens: maxTokens
            )
        }
    }

    /// Validate an API key by making a lightweight test call.
    static func validateApiKey(provider: AIProvider, apiKey: String) async -> Result<Bool, AIError> {
        Self.logger.info("Validating API key for \(provider.rawValue)")
        let testMessages: [[String: Any]] = [["role": "user", "content": "Hi"]]

        do {
            switch provider {
            case .anthropic:
                let _ = try await AnthropicClient.call(
                    messages: testMessages, system: nil, tools: [],
                    model: "claude-sonnet-4-20250514", apiKey: apiKey, maxTokens: 10, timeout: 15
                )
            case .openai:
                let _ = try await OpenAIClient.call(
                    messages: testMessages, system: nil, tools: [],
                    model: "gpt-4o-mini", apiKey: apiKey, maxTokens: 10, timeout: 15
                )
            }
            Self.logger.info("API key valid for \(provider.rawValue)")
            return .success(true)
        } catch let error as AIError {
            switch error {
            case .apiError(let code, _) where code == 401 || code == 403:
                Self.logger.warning("API key invalid for \(provider.rawValue)")
                return .failure(.invalidApiKey)
            default:
                Self.logger.error("Key validation error: \(error.localizedDescription)")
                return .failure(error)
            }
        } catch {
            Self.logger.error("Key validation unexpected error: \(error.localizedDescription)")
            return .failure(.apiError(statusCode: 0, message: error.localizedDescription))
        }
    }
}

/// Non-streaming AI response.
struct AIResponse: Sendable {
    let text: String
    let toolCalls: [ToolCall]
    let stopReason: StopReason
    let usage: TokenUsage?
}

enum StopReason: String, Sendable {
    case endTurn = "end_turn"
    case toolUse = "tool_use"
    case maxTokens = "max_tokens"
    case stop
    case unknown
}

struct TokenUsage: Sendable {
    let inputTokens: Int
    let outputTokens: Int
}

/// Events emitted during streaming.
enum StreamEvent: Sendable {
    case textDelta(String)
    case toolCallStart(id: String, name: String)
    case toolCallDelta(id: String, inputDelta: String)
    case toolCallComplete(id: String)
    case messageComplete(stopReason: StopReason)
    case error(String)
}
