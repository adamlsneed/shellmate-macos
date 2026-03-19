import Foundation
import os

/// Agentic tool-use loop: call AI → check for tool_use → execute tools → repeat.
/// Maximum 15 rounds (matching Electron app behavior).
actor ToolUseLoop {
    private static let logger = Logger(subsystem: "com.shellmate.app", category: "tool-loop")
    private let maxRounds = 15
    private let router = AIRouter()
    private let executor = ToolExecutor()

    /// Event emitted during the loop for UI updates.
    enum LoopEvent: Sendable {
        case textDelta(String)
        case toolCallStarted(id: String, name: String, input: String)
        case toolCallCompleted(id: String, result: String, isError: Bool)
        case roundComplete(round: Int)
        case finished(fullText: String)
        case error(String)
    }

    /// Run the agentic tool-use loop.
    func run(
        messages: [SendableDict],
        system: String,
        tools: [ToolDefinition],
        provider: AIProvider,
        model: String,
        apiKey: String,
        denyCategories: [ToolDenyCategory] = [],
        onEvent: @Sendable @escaping (LoopEvent) -> Void
    ) async {
        let availableTools = ToolDefinitions.available(denyCategories: denyCategories)
        var conversationMessages: [[String: Any]] = messages.map(\.dict)
        var fullText = ""

        for round in 1...maxRounds {
            Self.logger.info("Tool-use loop round \(round)")

            do {
                let response = try await router.call(
                    messages: conversationMessages,
                    system: system,
                    tools: availableTools,
                    provider: provider,
                    model: model,
                    apiKey: apiKey
                )

                if !response.text.isEmpty {
                    fullText += response.text
                    onEvent(.textDelta(response.text))
                }

                // If no tool calls, we're done
                guard response.stopReason == .toolUse, !response.toolCalls.isEmpty else {
                    onEvent(.finished(fullText: fullText))
                    return
                }

                // Build the assistant message with tool_use blocks
                var assistantContent: [[String: Any]] = []
                if !response.text.isEmpty {
                    assistantContent.append(["type": "text", "text": response.text])
                }

                var toolResults: [[String: Any]] = []
                for toolCall in response.toolCalls {
                    let inputData = try JSONEncoder().encode(toolCall.input)
                    let inputStr = String(data: inputData, encoding: .utf8) ?? "{}"

                    assistantContent.append([
                        "type": "tool_use",
                        "id": toolCall.id,
                        "name": toolCall.name,
                        "input": toolCall.input.mapValues(\.anyValue),
                    ])

                    onEvent(.toolCallStarted(id: toolCall.id, name: toolCall.name, input: inputStr))

                    let result = await executor.execute(
                        tool: toolCall.name,
                        input: toolCall.input
                    )

                    onEvent(.toolCallCompleted(id: toolCall.id, result: result.content, isError: result.isError))

                    toolResults.append([
                        "type": "tool_result",
                        "tool_use_id": toolCall.id,
                        "content": result.content,
                        "is_error": result.isError,
                    ])
                }

                // Append assistant message and tool results
                conversationMessages.append(["role": "assistant", "content": assistantContent])
                for toolResult in toolResults {
                    conversationMessages.append(["role": "user", "content": [toolResult]])
                }

                onEvent(.roundComplete(round: round))

            } catch {
                Self.logger.error("Tool-use loop error: \(error.localizedDescription)")
                onEvent(.error(error.localizedDescription))
                return
            }
        }

        Self.logger.warning("Tool-use loop hit max rounds (\(self.maxRounds))")
        onEvent(.finished(fullText: fullText))
    }
}

/// Sendable wrapper for [String: Any] dictionaries used in message passing.
/// These contain only JSON-safe value types (String, Int, Double, Bool, Array, Dictionary).
struct SendableDict: @unchecked Sendable {
    let dict: [String: Any]

    init(_ dict: [String: Any]) {
        self.dict = dict
    }
}
