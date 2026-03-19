import Foundation
import os

/// Client for the Anthropic Messages API (v1/messages).
enum AnthropicClient {
    private static let logger = Logger(subsystem: "com.shellmate.app", category: "anthropic")
    private static let baseURL = URL(string: "https://api.anthropic.com/v1/messages")!
    private static let defaultTimeout: TimeInterval = 15
    private static let streamingTimeout: TimeInterval = 300
    private static let maxRetries = 3
    private static let retryableStatusCodes: Set<Int> = [429, 500, 502, 503, 529]

    /// Non-streaming call to Anthropic API with timeout and retry.
    static func call(
        messages: [[String: Any]],
        system: String?,
        tools: [ToolDefinition],
        model: String,
        apiKey: String,
        maxTokens: Int,
        timeout: TimeInterval? = nil
    ) async throws -> AIResponse {
        let request = try buildRequest(
            messages: messages, system: system, tools: tools,
            model: model, apiKey: apiKey, maxTokens: maxTokens, stream: false,
            timeout: timeout ?? defaultTimeout
        )

        return try await withRetry(maxAttempts: maxRetries) {
            try Task.checkCancellation()

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AIError.invalidResponse
            }

            if retryableStatusCodes.contains(httpResponse.statusCode) {
                let body = String(data: data, encoding: .utf8) ?? "unknown error"
                let retryAfter = parseRetryAfter(httpResponse)
                throw RetryableError(
                    underlying: AIError.apiError(statusCode: httpResponse.statusCode, message: body),
                    retryAfter: retryAfter
                )
            }

            guard httpResponse.statusCode == 200 else {
                let body = String(data: data, encoding: .utf8) ?? "unknown error"
                throw AIError.apiError(statusCode: httpResponse.statusCode, message: body)
            }

            logRateLimitHeaders(httpResponse)
            return try parseResponse(data: data)
        }
    }

    /// Streaming call to Anthropic API with proper tool_use block tracking.
    static func stream(
        messages: [[String: Any]],
        system: String?,
        tools: [ToolDefinition],
        model: String,
        apiKey: String,
        maxTokens: Int,
        timeout: TimeInterval? = nil
    ) -> AsyncThrowingStream<StreamEvent, Error> {
        let request: URLRequest
        do {
            request = try buildRequest(
                messages: messages, system: system, tools: tools,
                model: model, apiKey: apiKey, maxTokens: maxTokens, stream: true,
                timeout: timeout ?? streamingTimeout
            )
        } catch {
            return AsyncThrowingStream { $0.finish(throwing: error) }
        }

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try Task.checkCancellation()
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)

                    guard let httpResponse = response as? HTTPURLResponse else {
                        continuation.yield(.error("Invalid response"))
                        continuation.finish(throwing: AIError.invalidResponse)
                        return
                    }

                    guard httpResponse.statusCode == 200 else {
                        var errorBody = ""
                        for try await line in bytes.lines {
                            errorBody += line
                            if errorBody.count > 2000 { break }
                        }
                        let error = AIError.apiError(statusCode: httpResponse.statusCode, message: errorBody)
                        continuation.yield(.error(error.localizedDescription))
                        continuation.finish(throwing: error)
                        return
                    }

                    logRateLimitHeaders(httpResponse)

                    // Track tool_use blocks by index for ID correlation
                    var toolIdsByIndex: [Int: String] = [:]

                    for try await line in bytes.lines {
                        try Task.checkCancellation()

                        guard line.hasPrefix("data: ") else { continue }
                        let jsonStr = String(line.dropFirst(6))
                        if jsonStr == "[DONE]" { break }

                        guard let jsonData = jsonStr.data(using: .utf8),
                              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                              let type = json["type"] as? String else { continue }

                        switch type {
                        case "content_block_start":
                            let index = json["index"] as? Int ?? 0
                            if let contentBlock = json["content_block"] as? [String: Any] {
                                let blockType = contentBlock["type"] as? String
                                if blockType == "tool_use",
                                   let id = contentBlock["id"] as? String,
                                   let name = contentBlock["name"] as? String {
                                    toolIdsByIndex[index] = id
                                    continuation.yield(.toolCallStart(id: id, name: name))
                                }
                            }

                        case "content_block_delta":
                            let index = json["index"] as? Int ?? 0
                            if let delta = json["delta"] as? [String: Any] {
                                let deltaType = delta["type"] as? String
                                if deltaType == "text_delta", let text = delta["text"] as? String {
                                    continuation.yield(.textDelta(text))
                                } else if deltaType == "input_json_delta",
                                          let partialJson = delta["partial_json"] as? String {
                                    let toolId = toolIdsByIndex[index] ?? "\(index)"
                                    continuation.yield(.toolCallDelta(id: toolId, inputDelta: partialJson))
                                }
                            }

                        case "content_block_stop":
                            let index = json["index"] as? Int ?? 0
                            if let toolId = toolIdsByIndex[index] {
                                continuation.yield(.toolCallComplete(id: toolId))
                            }

                        case "message_delta":
                            if let delta = json["delta"] as? [String: Any],
                               let stopReasonStr = delta["stop_reason"] as? String {
                                let reason = StopReason(rawValue: stopReasonStr) ?? .unknown
                                continuation.yield(.messageComplete(stopReason: reason))
                            }

                        case "message_stop":
                            continuation.yield(.messageComplete(stopReason: .endTurn))

                        case "error":
                            if let errorDict = json["error"] as? [String: Any],
                               let message = errorDict["message"] as? String {
                                continuation.yield(.error(message))
                                continuation.finish(throwing: AIError.apiError(statusCode: 0, message: message))
                                return
                            }

                        default:
                            break
                        }
                    }
                    continuation.finish()
                } catch is CancellationError {
                    continuation.yield(.error("Request cancelled"))
                    continuation.finish(throwing: AIError.cancelled)
                } catch {
                    continuation.yield(.error(error.localizedDescription))
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }

    // MARK: - Request Building

    static func buildRequest(
        messages: [[String: Any]],
        system: String?,
        tools: [ToolDefinition],
        model: String,
        apiKey: String,
        maxTokens: Int,
        stream: Bool,
        timeout: TimeInterval = 15
    ) throws -> URLRequest {
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

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

    // MARK: - Response Parsing

    static func parseResponse(data: Data) throws -> AIResponse {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AIError.invalidResponse
        }

        if let errorDict = json["error"] as? [String: Any],
           let message = errorDict["message"] as? String {
            let type = errorDict["type"] as? String ?? "api_error"
            throw AIError.apiError(statusCode: 0, message: "\(type): \(message)")
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

    // MARK: - Rate Limit Handling

    private static func logRateLimitHeaders(_ response: HTTPURLResponse) {
        if let remaining = response.value(forHTTPHeaderField: "anthropic-ratelimit-requests-remaining") {
            logger.info("Rate limit remaining: \(remaining)")
        }
        if let reset = response.value(forHTTPHeaderField: "anthropic-ratelimit-requests-reset") {
            logger.info("Rate limit resets: \(reset)")
        }
        if let tokensRemaining = response.value(forHTTPHeaderField: "anthropic-ratelimit-tokens-remaining") {
            logger.info("Token limit remaining: \(tokensRemaining)")
        }
    }

    private static func parseRetryAfter(_ response: HTTPURLResponse) -> TimeInterval? {
        if let retryAfter = response.value(forHTTPHeaderField: "retry-after"),
           let seconds = TimeInterval(retryAfter) {
            return seconds
        }
        return nil
    }
}

// MARK: - Retry Infrastructure

/// Error wrapper indicating the operation should be retried.
struct RetryableError: Error {
    let underlying: Error
    let retryAfter: TimeInterval?
}

/// Execute an async operation with exponential backoff retry.
func withRetry<T: Sendable>(
    maxAttempts: Int,
    initialDelay: TimeInterval = 1.0,
    maxDelay: TimeInterval = 30.0,
    operation: @Sendable () async throws -> T
) async throws -> T {
    var lastError: Error?
    var delay = initialDelay

    for attempt in 1...maxAttempts {
        do {
            return try await operation()
        } catch let error as RetryableError {
            lastError = error.underlying
            let waitTime = error.retryAfter ?? delay
            Logger(subsystem: "com.shellmate.app", category: "retry")
                .warning("Attempt \(attempt)/\(maxAttempts) failed, retrying in \(waitTime)s: \(error.underlying.localizedDescription)")
            if attempt < maxAttempts {
                try await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
                delay = min(delay * 2, maxDelay)
            }
        } catch is CancellationError {
            throw AIError.cancelled
        } catch {
            throw error
        }
    }

    throw lastError ?? AIError.invalidResponse
}

/// AI-related errors.
enum AIError: LocalizedError {
    case invalidResponse
    case apiError(statusCode: Int, message: String)
    case noApiKey
    case cancelled
    case networkUnavailable
    case rateLimited(retryAfter: TimeInterval?)
    case invalidApiKey

    var errorDescription: String? {
        switch self {
        case .invalidResponse: "Invalid response from AI provider"
        case .apiError(let code, let msg): "API error (\(code)): \(msg)"
        case .noApiKey: "No API key configured"
        case .cancelled: "Request was cancelled"
        case .networkUnavailable: "Network is unavailable — check your internet connection"
        case .rateLimited(let retryAfter):
            if let seconds = retryAfter {
                "Rate limited — try again in \(Int(seconds)) seconds"
            } else {
                "Rate limited — try again shortly"
            }
        case .invalidApiKey: "API key is invalid — check your settings"
        }
    }
}
