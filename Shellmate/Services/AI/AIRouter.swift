import Foundation

/// Routes AI requests to the appropriate provider client.
struct AIRouter: Sendable {
    /// Make an AI call using the configured provider.
    /// Returns the response text and any tool calls.
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
                messages: messages,
                system: system,
                tools: tools,
                model: model,
                apiKey: apiKey,
                maxTokens: maxTokens
            )
        case .openai:
            return try await OpenAIClient.call(
                messages: messages,
                system: system,
                tools: tools,
                model: model,
                apiKey: apiKey,
                maxTokens: maxTokens
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
                messages: messages,
                system: system,
                tools: tools,
                model: model,
                apiKey: apiKey,
                maxTokens: maxTokens
            )
        case .openai:
            return OpenAIClient.stream(
                messages: messages,
                system: system,
                tools: tools,
                model: model,
                apiKey: apiKey,
                maxTokens: maxTokens
            )
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
