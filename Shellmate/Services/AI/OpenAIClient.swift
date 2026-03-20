import Foundation
import os

/// Client for the OpenAI Chat Completions API (v1/chat/completions).
enum OpenAIClient {
    private static let logger = Logger(subsystem: "com.shellmate.app", category: "openai")
    private static let baseURL = URL(string: "https://api.openai.com/v1/chat/completions")!
    private static let defaultTimeout: TimeInterval = 15
    private static let streamingTimeout: TimeInterval = 300
    private static let maxRetries = 3
    private static let retryableStatusCodes: Set<Int> = [429, 500, 502, 503]

    /// Non-streaming call to OpenAI API with timeout and retry.
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
                let body = String(String(data: data, encoding: .utf8)?.prefix(500) ?? "unknown error")
                let retryAfter = parseRetryAfter(httpResponse)
                throw RetryableError(
                    underlying: AIError.apiError(statusCode: httpResponse.statusCode, message: body),
                    retryAfter: retryAfter
                )
            }
            guard httpResponse.statusCode == 200 else {
                let body = String(String(data: data, encoding: .utf8)?.prefix(500) ?? "unknown error")
                throw AIError.apiError(statusCode: httpResponse.statusCode, message: body)
            }
            logRateLimitHeaders(httpResponse)
            return try parseResponse(data: data)
        }
    }

    /// Streaming call to OpenAI API with proper tool_call accumulation.
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

                    // Track tool call IDs by index
                    var toolIdsByIndex: [Int: String] = [:]

                    for try await line in bytes.lines {
                        try Task.checkCancellation()
                        guard line.hasPrefix("data: ") else { continue }
                        let jsonStr = String(line.dropFirst(6))
                        if jsonStr == "[DONE]" { break }

                        guard let jsonData = jsonStr.data(using: .utf8),
                              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                              let choices = json["choices"] as? [[String: Any]],
                              let choice = choices.first,
                              let delta = choice["delta"] as? [String: Any] else { continue }

                        if let content = delta["content"] as? String {
                            continuation.yield(.textDelta(content))
                        }
                        if let toolCalls = delta["tool_calls"] as? [[String: Any]] {
                            for tc in toolCalls {
                                let index = tc["index"] as? Int ?? 0
                                if let id = tc["id"] as? String {
                                    toolIdsByIndex[index] = id
                                    if let function = tc["function"] as? [String: Any],
                                       let name = function["name"] as? String {
                                        continuation.yield(.toolCallStart(id: id, name: name))
                                    }
                                }
                                if let function = tc["function"] as? [String: Any],
                                   let args = function["arguments"] as? String, !args.isEmpty {
                                    let id = toolIdsByIndex[index] ?? "\(index)"
                                    continuation.yield(.toolCallDelta(id: id, inputDelta: args))
                                }
                            }
                        }
                        if let finishReason = choice["finish_reason"] as? String, finishReason != "null" {
                            for (_, id) in toolIdsByIndex {
                                continuation.yield(.toolCallComplete(id: id))
                            }
                            toolIdsByIndex.removeAll()
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
                    continuation.finish()
                } catch is CancellationError {
                    continuation.yield(.error("Request cancelled"))
                    continuation.finish(throwing: AIError.cancelled)
                } catch {
                    continuation.yield(.error(error.localizedDescription))
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { @Sendable _ in task.cancel() }
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
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        var allMessages = messages
        if let system {
            allMessages.insert(["role": "system", "content": system], at: 0)
        }

        var body: [String: Any] = [
            "model": model,
            "messages": allMessages,
            "max_tokens": maxTokens,
        ]
        if stream {
            body["stream"] = true
            body["stream_options"] = ["include_usage": true]
        }
        if !tools.isEmpty {
            body["tools"] = tools.toOpenAIFormat()
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
            throw AIError.apiError(statusCode: 0, message: message)
        }
        guard let choices = json["choices"] as? [[String: Any]],
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

    // MARK: - Rate Limit Handling

    private static func logRateLimitHeaders(_ response: HTTPURLResponse) {
        if let remaining = response.value(forHTTPHeaderField: "x-ratelimit-remaining-requests") {
            logger.info("Rate limit remaining requests: \(remaining)")
        }
        if let tokensRemaining = response.value(forHTTPHeaderField: "x-ratelimit-remaining-tokens") {
            logger.info("Rate limit remaining tokens: \(tokensRemaining)")
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
