import Foundation
import os

/// Client for the Anthropic Messages API (v1/messages).
enum AnthropicClient {
    private static let logger = Logger(subsystem: "com.shellmate.app", category: "anthropic")
    private static let baseURL = URL(string: "https://api.anthropic.com/v1/messages")!

    /// Non-streaming call to Anthropic API.
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

    /// Streaming call to Anthropic API.
    static func stream(
        messages: [[String: Any]],
        system: String?,
        tools: [ToolDefinition],
        model: String,
        apiKey: String,
        maxTokens: Int
    ) -> AsyncThrowingStream<StreamEvent, Error> {
        // Build request outside the closure to avoid Sendable capture issues
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

                    // Parse SSE stream
                    for try await line in bytes.lines {
                        if line.hasPrefix("data: ") {
                            let jsonStr = String(line.dropFirst(6))
                            if jsonStr == "[DONE]" { break }

                            guard let jsonData = jsonStr.data(using: .utf8),
                                  let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                                  let type = json["type"] as? String else { continue }

                            switch type {
                            case "content_block_start":
                                if let contentBlock = json["content_block"] as? [String: Any],
                                   contentBlock["type"] as? String == "tool_use",
                                   let id = contentBlock["id"] as? String,
                                   let name = contentBlock["name"] as? String {
                                    continuation.yield(.toolCallStart(id: id, name: name))
                                }

                            case "content_block_delta":
                                if let delta = json["delta"] as? [String: Any] {
                                    if let text = delta["text"] as? String {
                                        continuation.yield(.textDelta(text))
                                    } else if let partialJson = delta["partial_json"] as? String {
                                        if let index = json["index"] as? Int {
                                            // Tool input delta — use index to find tool ID later
                                            continuation.yield(.toolCallDelta(id: "\(index)", inputDelta: partialJson))
                                        }
                                    }
                                }

                            case "content_block_stop":
                                if let index = json["index"] as? Int {
                                    continuation.yield(.toolCallComplete(id: "\(index)"))
                                }

                            case "message_delta":
                                if let delta = json["delta"] as? [String: Any],
                                   let stopReasonStr = delta["stop_reason"] as? String {
                                    let reason = StopReason(rawValue: stopReasonStr) ?? .unknown
                                    continuation.yield(.messageComplete(stopReason: reason))
                                }

                            case "message_stop":
                                continuation.yield(.messageComplete(stopReason: .endTurn))

                            default:
                                break
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
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        // OAuth vs API key auth
        if isOAuthToken(apiKey) {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        } else {
            request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        }

        var body: [String: Any] = [
            "model": model,
            "messages": messages,
            "max_tokens": maxTokens,
        ]
        if let system { body["system"] = system }
        if stream { body["stream"] = true }
        if !tools.isEmpty {
            body["tools"] = ToolDefinitions.toAnthropicFormat(tools)
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    private static func parseResponse(data: Data) throws -> AIResponse {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AIError.invalidResponse
        }

        var text = ""
        var toolCalls: [ToolCall] = []

        if let content = json["content"] as? [[String: Any]] {
            for block in content {
                let blockType = block["type"] as? String
                if blockType == "text", let t = block["text"] as? String {
                    text += t
                } else if blockType == "tool_use",
                          let id = block["id"] as? String,
                          let name = block["name"] as? String,
                          let input = block["input"] as? [String: Any] {
                    let inputData = try JSONSerialization.data(withJSONObject: input)
                    let decodedInput = try JSONDecoder().decode([String: JSONValue].self, from: inputData)
                    toolCalls.append(ToolCall(id: id, name: name, input: decodedInput))
                }
            }
        }

        let stopReasonStr = json["stop_reason"] as? String ?? "unknown"
        let stopReason = StopReason(rawValue: stopReasonStr) ?? .unknown

        var usage: TokenUsage?
        if let usageDict = json["usage"] as? [String: Int] {
            usage = TokenUsage(
                inputTokens: usageDict["input_tokens"] ?? 0,
                outputTokens: usageDict["output_tokens"] ?? 0
            )
        }

        return AIResponse(text: text, toolCalls: toolCalls, stopReason: stopReason, usage: usage)
    }
}

/// AI-related errors.
enum AIError: LocalizedError {
    case invalidResponse
    case apiError(statusCode: Int, message: String)
    case noApiKey
    case cancelled

    var errorDescription: String? {
        switch self {
        case .invalidResponse: "Invalid response from AI provider"
        case .apiError(let code, let msg): "API error (\(code)): \(msg)"
        case .noApiKey: "No API key configured"
        case .cancelled: "Request was cancelled"
        }
    }
}
