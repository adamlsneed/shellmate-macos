import Foundation
import Testing
@testable import Shellmate

@Suite("AnthropicClient")
struct AnthropicClientTests {

    // MARK: - Request Building

    @Test("builds request with API key auth")
    func testBuildRequestApiKey() throws {
        let request = try AnthropicClient.buildRequest(
            messages: [["role": "user", "content": "Hello"]],
            system: "You are helpful",
            tools: [],
            model: "claude-sonnet-4-20250514",
            apiKey: "sk-ant-api-test123",
            maxTokens: 1024,
            stream: false
        )

        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "X-API-Key") == "sk-ant-api-test123")
        #expect(request.value(forHTTPHeaderField: "anthropic-version") == "2023-06-01")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(request.value(forHTTPHeaderField: "anthropic-beta") == nil)

        let body = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
        #expect(body["model"] as? String == "claude-sonnet-4-20250514")
        #expect(body["max_tokens"] as? Int == 1024)
        #expect(body["system"] as? String == "You are helpful")
        #expect(body["stream"] == nil)
    }

    @Test("builds request with OAuth auth")
    func testBuildRequestOAuth() throws {
        let request = try AnthropicClient.buildRequest(
            messages: [["role": "user", "content": "Hello"]],
            system: nil,
            tools: [],
            model: "claude-sonnet-4-20250514",
            apiKey: "sk-ant-oat-mytoken",
            maxTokens: 4096,
            stream: false
        )

        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer sk-ant-oat-mytoken")
        #expect(request.value(forHTTPHeaderField: "anthropic-beta") == "oauth-2025-04-20")
        #expect(request.value(forHTTPHeaderField: "X-API-Key") == nil)
    }

    @Test("builds streaming request with stream flag")
    func testBuildStreamingRequest() throws {
        let request = try AnthropicClient.buildRequest(
            messages: [["role": "user", "content": "Hello"]],
            system: nil,
            tools: [],
            model: "claude-sonnet-4-20250514",
            apiKey: "sk-ant-api-test123",
            maxTokens: 4096,
            stream: true
        )

        let body = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
        #expect(body["stream"] as? Bool == true)
    }

    @Test("builds request with tools")
    func testBuildRequestWithTools() throws {
        let tools = [ToolDefinitions.shellExec, ToolDefinitions.fileRead]
        let request = try AnthropicClient.buildRequest(
            messages: [["role": "user", "content": "Hello"]],
            system: nil,
            tools: tools,
            model: "claude-sonnet-4-20250514",
            apiKey: "sk-ant-api-test",
            maxTokens: 4096,
            stream: false
        )

        let body = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
        let toolsArray = body["tools"] as? [[String: Any]]
        #expect(toolsArray?.count == 2)
        #expect(toolsArray?[0]["name"] as? String == "shell_exec")
        #expect(toolsArray?[1]["name"] as? String == "file_read")
    }

    @Test("request timeout is configurable")
    func testRequestTimeout() throws {
        let request = try AnthropicClient.buildRequest(
            messages: [],
            system: nil,
            tools: [],
            model: "claude-sonnet-4-20250514",
            apiKey: "test",
            maxTokens: 100,
            stream: false,
            timeout: 30
        )

        #expect(request.timeoutInterval == 30)
    }

    // MARK: - Response Parsing

    @Test("parses text-only response")
    func testParseTextResponse() throws {
        let json: [String: Any] = [
            "content": [
                ["type": "text", "text": "Hello! How can I help?"]
            ],
            "stop_reason": "end_turn",
            "usage": ["input_tokens": 10, "output_tokens": 8],
        ]
        let data = try JSONSerialization.data(withJSONObject: json)

        let response = try AnthropicClient.parseResponse(data: data)
        #expect(response.text == "Hello! How can I help?")
        #expect(response.toolCalls.isEmpty)
        #expect(response.stopReason == .endTurn)
        #expect(response.usage?.inputTokens == 10)
        #expect(response.usage?.outputTokens == 8)
    }

    @Test("parses tool_use response")
    func testParseToolUseResponse() throws {
        let json: [String: Any] = [
            "content": [
                ["type": "text", "text": "Let me check that."],
                [
                    "type": "tool_use",
                    "id": "toolu_123",
                    "name": "shell_exec",
                    "input": ["command": "ls -la"],
                ],
            ],
            "stop_reason": "tool_use",
        ]
        let data = try JSONSerialization.data(withJSONObject: json)

        let response = try AnthropicClient.parseResponse(data: data)
        #expect(response.text == "Let me check that.")
        #expect(response.toolCalls.count == 1)
        #expect(response.toolCalls[0].id == "toolu_123")
        #expect(response.toolCalls[0].name == "shell_exec")
        #expect(response.toolCalls[0].input["command"]?.stringValue == "ls -la")
        #expect(response.stopReason == .toolUse)
    }

    @Test("parses multiple tool_use blocks")
    func testParseMultipleToolUse() throws {
        let json: [String: Any] = [
            "content": [
                [
                    "type": "tool_use",
                    "id": "toolu_1",
                    "name": "file_read",
                    "input": ["path": "/tmp/a.txt"],
                ],
                [
                    "type": "tool_use",
                    "id": "toolu_2",
                    "name": "file_read",
                    "input": ["path": "/tmp/b.txt"],
                ],
            ],
            "stop_reason": "tool_use",
        ]
        let data = try JSONSerialization.data(withJSONObject: json)

        let response = try AnthropicClient.parseResponse(data: data)
        #expect(response.toolCalls.count == 2)
        #expect(response.toolCalls[0].id == "toolu_1")
        #expect(response.toolCalls[1].id == "toolu_2")
    }

    @Test("parses error response body")
    func testParseErrorResponse() throws {
        let json: [String: Any] = [
            "error": [
                "type": "invalid_request_error",
                "message": "max_tokens must be positive",
            ]
        ]
        let data = try JSONSerialization.data(withJSONObject: json)

        #expect(throws: AIError.self) {
            try AnthropicClient.parseResponse(data: data)
        }
    }

    @Test("handles invalid JSON gracefully")
    func testParseInvalidJSON() throws {
        let data = "not json".data(using: .utf8)!

        #expect(throws: Error.self) {
            try AnthropicClient.parseResponse(data: data)
        }
    }
}
