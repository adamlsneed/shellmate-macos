import Foundation
import os

/// Client for the OpenAI Chat Completions API (v1/chat/completions).
enum OpenAIClient {
    private static let logger = Logger(subsystem: "com.shellmate.app", category: "openai")
    private static let baseURL = URL(string: "https://api.openai.com/v1/chat/completions")!

    /// Non-streaming call to OpenAI API.
    static func call(
        messages: [[String: Any]],
        system: String?,
        tools: [ToolDefinition],
        model: String,
        apiKey: String,
        maxTokens: Int
    ) async throws -> AIResponse {
        let request = try buildRequest(
            messages: messages, system: system, tools: tools,
            model: model, apiKey: apiKey, maxTokens: maxTokens, stream: false
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "unknown error"
            throw AIError.apiError(statusCode: httpResponse.statusCode, message: body)
        }

        return try parseResponse(data: data)
    }

    /// Streaming call to OpenAI API.
    static func stream(
        messages: [[String: Any]],
        system: String?,
        tools: [ToolDefinition],
        model: String,
        apiKey: String,
        maxTokens: Int
    ) -> AsyncThrowingStream<StreamEvent, Error> {
        let request: URLRequest
        do {
            request = try buildRequest(
                messages: messages, system: system, tools: tools,
                model: model, apiKey: apiKey, maxTokens: maxTokens, stream: true
            )
        } catch {
            return AsyncThrowingStream { $0.finish(throwing: error) }
        }

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)

                    guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                        continuation.yield(.error("API returned non-200 status"))
                        continuation.finish()
                        return
                    }

                    for try await line in bytes.lines {
                        if line.hasPrefix("data: ") {
                            let jsonStr = String(line.dropFirst(6))
                            if jsonStr == "[DONE]" { break }

                            guard let jsonData = jsonStr.data(using: .utf8),
                                  let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                                  let choices = json["choices"] as? [[String: Any]],
                                  let choice = choices.first,
                                  let delta = choice["delta"] as? [String: Any] else { continue }

                            // Text content
                            if let content = delta["content"] as? String {
                                continuation.yield(.textDelta(content))
                            }

                            // Tool calls
                            if let toolCalls = delta["tool_calls"] as? [[String: Any]] {
                                for tc in toolCalls {
                                    let index = tc["index"] as? Int ?? 0
                                    if let id = tc["id"] as? String,
                                       let function = tc["function"] as? [String: Any],
                                       let name = function["name"] as? String {
                                        continuation.yield(.toolCallStart(id: id, name: name))
                                    }
                                    if let function = tc["function"] as? [String: Any],
                                       let args = function["arguments"] as? String, !args.isEmpty {
                                        let id = tc["id"] as? String ?? "\(index)"
                                        continuation.yield(.toolCallDelta(id: id, inputDelta: args))
                                    }
                                }
                            }

                            // Finish reason
                            if let finishReason = choice["finish_reason"] as? String, finishReason != "null" {
                                let reason: StopReason
                                switch finishReason {
                                case "stop": reason = .endTurn
                                case "tool_calls": reason = .toolUse
                                case "length": reason = .maxTokens
                                default: reason = .unknown
                                }
                                continuation.yield(.messageComplete(stopReason: reason))
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.yield(.error(error.localizedDescription))
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Private

    private static func buildRequest(
        messages: [[String: Any]],
        system: String?,
        tools: [ToolDefinition],
        model: String,
        apiKey: String,
        maxTokens: Int,
        stream: Bool
    ) throws -> URLRequest {
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        // OpenAI puts system message in the messages array
        var allMessages = messages
        if let system {
            allMessages.insert(["role": "system", "content": system], at: 0)
        }

        var body: [String: Any] = [
            "model": model,
            "messages": allMessages,
            "max_tokens": maxTokens,
        ]
        if stream { body["stream"] = true }
        if !tools.isEmpty {
            body["tools"] = ToolDefinitions.toOpenAIFormat(tools)
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    private static func parseResponse(data: Data) throws -> AIResponse {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let choice = choices.first,
              let message = choice["message"] as? [String: Any] else {
            throw AIError.invalidResponse
        }

        let text = message["content"] as? String ?? ""

        var toolCalls: [ToolCall] = []
        if let tcs = message["tool_calls"] as? [[String: Any]] {
            for tc in tcs {
                guard let id = tc["id"] as? String,
                      let function = tc["function"] as? [String: Any],
                      let name = function["name"] as? String,
                      let argsStr = function["arguments"] as? String,
                      let argsData = argsStr.data(using: .utf8) else { continue }
                let input = (try? JSONDecoder().decode([String: JSONValue].self, from: argsData)) ?? [:]
                toolCalls.append(ToolCall(id: id, name: name, input: input))
            }
        }

        let finishReason = choice["finish_reason"] as? String ?? "unknown"
        let stopReason: StopReason
        switch finishReason {
        case "stop": stopReason = .endTurn
        case "tool_calls": stopReason = .toolUse
        case "length": stopReason = .maxTokens
        default: stopReason = .unknown
        }

        var usage: TokenUsage?
        if let usageDict = json["usage"] as? [String: Int] {
            usage = TokenUsage(
                inputTokens: usageDict["prompt_tokens"] ?? 0,
                outputTokens: usageDict["completion_tokens"] ?? 0
            )
        }

        return AIResponse(text: text, toolCalls: toolCalls, stopReason: stopReason, usage: usage)
    }
}
