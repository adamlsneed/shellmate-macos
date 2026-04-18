import Foundation
import os

/// Agentic tool-use loop: call AI -> check for tool_use -> execute tools -> repeat.
/// Maximum 15 rounds (matching Electron app behavior).
actor ToolUseLoop {
    private static let logger = Logger(subsystem: "com.shellmate.app", category: "tool-loop")
    private let maxRounds = 15
    private let router = AIRouter()
    private let executor: ToolExecutor
    private let categoryResolver = CategoryResolver()

    init(executor: ToolExecutor) {
        self.executor = executor
    }

    /// Event emitted during the loop for UI updates.
    enum LoopEvent: Sendable {
        case textDelta(String)
        case toolCallStarted(id: String, name: String, input: String)
        case toolCallCompleted(id: String, result: String, isError: Bool)
        case roundComplete(round: Int)
        case finished(fullText: String)
        case error(String)
    }

    /// A tool call being assembled from streaming events.
    private struct PendingToolCall {
        let id: String
        let name: String
        var inputJSON: String = ""
    }

    /// Run the agentic tool-use loop.
    /// Supports cancellation via Task.cancel() -- checks at each round boundary.
    func run(
        messages: [SendableDict],
        system: String,
        provider: AIProvider,
        model: String,
        apiKey: String,
        enabledCategories: Set<ToolCategory>,
        denyCategories: [ToolDenyCategory] = [],
        onEvent: @Sendable @escaping (LoopEvent) -> Void
    ) async {
        let lastMessage = messages.last?.dict["content"] as? String ?? ""
        let resolvedCategories = categoryResolver.resolve(
            message: lastMessage,
            enabledCategories: enabledCategories
        )
        let availableTools = await executor.registry.toolSchemas(for: resolvedCategories, denyCategories: denyCategories)
        var conversationMessages: [[String: Any]] = messages.map(\.dict)
        var fullText = ""

        for round in 1...maxRounds {
            guard !Task.isCancelled else {
                Self.logger.info("Tool-use loop cancelled at round \(round)")
                onEvent(.error("Cancelled"))
                return
            }

            Self.logger.info("Tool-use loop round \(round)")

            do {
                // nonisolated(unsafe) is safe here -- conversationMessages contains only
                // JSON-safe value types which are effectively value semantics.
                nonisolated(unsafe) let messagesCopy = conversationMessages
                let stream = router.stream(
                    messages: messagesCopy,
                    system: system,
                    tools: availableTools,
                    provider: provider,
                    model: model,
                    apiKey: apiKey
                )

                var roundText = ""
                var pendingTools: [String: PendingToolCall] = [:]
                var completedToolCalls: [ToolCall] = []
                var stopReason: StopReason = .endTurn

                for try await event in stream {
                    switch event {
                    case .textDelta(let delta):
                        roundText += delta
                        fullText += delta
                        onEvent(.textDelta(delta))

                    case .toolCallStart(let id, let name):
                        pendingTools[id] = PendingToolCall(id: id, name: name)

                    case .toolCallDelta(let id, let delta):
                        pendingTools[id]?.inputJSON += delta

                    case .toolCallComplete(let id):
                        guard let pending = pendingTools[id] else { continue }
                        let inputDict: [String: JSONValue]
                        if let data = pending.inputJSON.data(using: .utf8),
                           let parsed = try? JSONDecoder().decode([String: JSONValue].self, from: data) {
                            inputDict = parsed
                        } else {
                            inputDict = [:]
                        }
                        completedToolCalls.append(ToolCall(id: pending.id, name: pending.name, input: inputDict))

                    case .messageComplete(let reason):
                        stopReason = reason

                    case .error(let msg):
                        throw AIError.apiError(statusCode: 0, message: msg)
                    }
                }

                guard stopReason == .toolUse, !completedToolCalls.isEmpty else {
                    onEvent(.finished(fullText: fullText))
                    return
                }

                let response = AIResponse(
                    text: roundText,
                    toolCalls: completedToolCalls,
                    stopReason: stopReason,
                    usage: nil
                )

                switch provider {
                case .anthropic:
                    try await appendAnthropicRound(
                        response: response,
                        conversationMessages: &conversationMessages,
                        onEvent: onEvent
                    )
                case .openai:
                    try await appendOpenAIRound(
                        response: response,
                        conversationMessages: &conversationMessages,
                        onEvent: onEvent
                    )
                }

                onEvent(.roundComplete(round: round))

            } catch is CancellationError {
                Self.logger.info("Tool-use loop cancelled during round \(round)")
                onEvent(.error("Cancelled"))
                return
            } catch {
                Self.logger.error("Tool-use loop error: \(error.localizedDescription)")
                onEvent(.error(error.localizedDescription))
                return
            }
        }

        Self.logger.warning("Tool-use loop hit max rounds (\(self.maxRounds))")
        fullText += "\n\n[Reached maximum tool rounds]"
        onEvent(.finished(fullText: fullText))
    }

    // MARK: - Anthropic Round

    private func appendAnthropicRound(
        response: AIResponse,
        conversationMessages: inout [[String: Any]],
        onEvent: @Sendable @escaping (LoopEvent) -> Void
    ) async throws {
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
            let result = await executor.execute(tool: toolCall.name, input: toolCall.input)
            onEvent(.toolCallCompleted(id: toolCall.id, result: result.content, isError: result.isError))

            toolResults.append([
                "type": "tool_result",
                "tool_use_id": toolCall.id,
                "content": result.content,
                "is_error": result.isError,
            ])
        }

        conversationMessages.append(["role": "assistant", "content": assistantContent])
        conversationMessages.append(["role": "user", "content": toolResults])
    }

    // MARK: - OpenAI Round

    private func appendOpenAIRound(
        response: AIResponse,
        conversationMessages: inout [[String: Any]],
        onEvent: @Sendable @escaping (LoopEvent) -> Void
    ) async throws {
        var assistantMessage: [String: Any] = ["role": "assistant"]
        if !response.text.isEmpty {
            assistantMessage["content"] = response.text
        }

        var openAIToolCalls: [[String: Any]] = []
        for toolCall in response.toolCalls {
            let inputData = try JSONEncoder().encode(toolCall.input)
            let inputStr = String(data: inputData, encoding: .utf8) ?? "{}"
            openAIToolCalls.append([
                "id": toolCall.id,
                "type": "function",
                "function": [
                    "name": toolCall.name,
                    "arguments": inputStr,
                ] as [String: Any],
            ])
        }
        assistantMessage["tool_calls"] = openAIToolCalls
        conversationMessages.append(assistantMessage)

        for toolCall in response.toolCalls {
            let inputData = try JSONEncoder().encode(toolCall.input)
            let inputStr = String(data: inputData, encoding: .utf8) ?? "{}"

            onEvent(.toolCallStarted(id: toolCall.id, name: toolCall.name, input: inputStr))
            let result = await executor.execute(tool: toolCall.name, input: toolCall.input)
            onEvent(.toolCallCompleted(id: toolCall.id, result: result.content, isError: result.isError))

            conversationMessages.append([
                "role": "tool",
                "tool_call_id": toolCall.id,
                "content": result.content,
            ])
        }
    }
}

/// Sendable wrapper for [String: Any] dictionaries used in message passing.
struct SendableDict: @unchecked Sendable {
    let dict: [String: Any]

    init(_ dict: [String: Any]) {
        self.dict = dict
    }
}
