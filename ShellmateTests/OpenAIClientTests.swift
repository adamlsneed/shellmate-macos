import Foundation
import Testing
@testable import Shellmate

@Suite("OpenAIClient")
struct OpenAIClientTests {

    // MARK: - Request Building

    @Test("builds request with Bearer auth")
    func testBuildRequest() throws {
        let request = try OpenAIClient.buildRequest(
            messages: [["role": "user", "content": "Hello"]],
            system: "You are helpful",
            tools: [],
            model: "gpt-4o",
            apiKey: "sk-proj-test123",
            maxTokens: 1024,
            stream: false
        )

        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer sk-proj-test123")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")

        let body = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
        #expect(body["model"] as? String == "gpt-4o")
        #expect(body["max_tokens"] as? Int == 1024)

        // System message should be prepended to messages array
        let messages = body["messages"] as? [[String: Any]]
        #expect(messages?.count == 2)
        #expect(messages?[0]["role"] as? String == "system")
        #expect(messages?[0]["content"] as? String == "You are helpful")
        #expect(messages?[1]["role"] as? String == "user")
    }

    @Test("builds request without system message")
    func testBuildRequestNoSystem() throws {
        let request = try OpenAIClient.buildRequest(
            messages: [["role": "user", "content": "Hello"]],
            system: nil,
            tools: [],
            model: "gpt-4o",
            apiKey: "sk-proj-test",
            maxTokens: 1024,
            stream: false
        )

        let body = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
        let messages = body["messages"] as? [[String: Any]]
        #expect(messages?.count == 1)
        #expect(messages?[0]["role"] as? String == "user")
    }

    @Test("builds streaming request with stream_options")
    func testBuildStreamingRequest() throws {
        let request = try OpenAIClient.buildRequest(
            messages: [["role": "user", "content": "Hello"]],
            system: nil,
            tools: [],
            model: "gpt-4o",
            apiKey: "sk-proj-test",
            maxTokens: 4096,
            stream: true
        )

        let body = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
        #expect(body["stream"] as? Bool == true)
        let streamOptions = body["stream_options"] as? [String: Any]
        #expect(streamOptions?["include_usage"] as? Bool == true)
    }

    @Test("builds request with tools in function format")
    func testBuildRequestWithTools() throws {
        let tools = [ToolDefinition(name: "web_search", description: "Search the web", inputSchema: ToolInputSchema(type: "object", properties: ["query": ToolProperty(type: "string", description: "The query")], required: ["query"]))]
        let request = try OpenAIClient.buildRequest(
            messages: [["role": "user", "content": "Search"]],
            system: nil,
            tools: tools,
            model: "gpt-4o",
            apiKey: "sk-proj-test",
            maxTokens: 4096,
            stream: false
        )

        let body = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
        let toolsArray = body["tools"] as? [[String: Any]]
        #expect(toolsArray?.count == 1)
        #expect(toolsArray?[0]["type"] as? String == "function")
        let fn = toolsArray?[0]["function"] as? [String: Any]
        #expect(fn?["name"] as? String == "web_search")
    }

    @Test("request timeout is configurable")
    func testRequestTimeout() throws {
        let request = try OpenAIClient.buildRequest(
            messages: [],
            system: nil,
            tools: [],
            model: "gpt-4o",
            apiKey: "test",
            maxTokens: 100,
            stream: false,
            timeout: 45
        )

        #expect(request.timeoutInterval == 45)
    }

    // MARK: - Response Parsing

    @Test("parses text-only response")
    func testParseTextResponse() throws {
        let json: [String: Any] = [
            "choices": [
                [
                    "message": [
                        "role": "assistant",
                        "content": "Hello! How can I help?",
                    ],
                    "finish_reason": "stop",
                ] as [String: Any]
            ],
            "usage": ["prompt_tokens": 15, "completion_tokens": 7],
        ]
        let data = try JSONSerialization.data(withJSONObject: json)

        let response = try OpenAIClient.parseResponse(data: data)
        #expect(response.text == "Hello! How can I help?")
        #expect(response.toolCalls.isEmpty)
        #expect(response.stopReason == .endTurn)
        #expect(response.usage?.inputTokens == 15)
        #expect(response.usage?.outputTokens == 7)
    }

    @Test("parses tool_calls response")
    func testParseToolCallsResponse() throws {
        let json: [String: Any] = [
            "choices": [
                [
                    "message": [
                        "role": "assistant",
                        "content": NSNull(),
                        "tool_calls": [
                            [
                                "id": "call_abc123",
                                "type": "function",
                                "function": [
                                    "name": "shell_exec",
                                    "arguments": "{\"command\":\"ls -la\"}",
                                ],
                            ] as [String: Any]
                        ],
                    ] as [String: Any],
                    "finish_reason": "tool_calls",
                ] as [String: Any]
            ],
        ]
        let data = try JSONSerialization.data(withJSONObject: json)

        let response = try OpenAIClient.parseResponse(data: data)
        #expect(response.toolCalls.count == 1)
        #expect(response.toolCalls[0].id == "call_abc123")
        #expect(response.toolCalls[0].name == "shell_exec")
        #expect(response.toolCalls[0].input["command"]?.stringValue == "ls -la")
        #expect(response.stopReason == .toolUse)
    }

    @Test("parses error response body")
    func testParseErrorResponse() throws {
        let json: [String: Any] = [
            "error": [
                "message": "Invalid API key",
                "type": "authentication_error",
            ]
        ]
        let data = try JSONSerialization.data(withJSONObject: json)

        #expect(throws: AIError.self) {
            try OpenAIClient.parseResponse(data: data)
        }
    }

    @Test("handles missing choices gracefully")
    func testParseMissingChoices() throws {
        let json: [String: Any] = ["id": "test"]
        let data = try JSONSerialization.data(withJSONObject: json)

        #expect(throws: AIError.self) {
            try OpenAIClient.parseResponse(data: data)
        }
    }

    @Test("parses max_tokens finish reason")
    func testParseMaxTokens() throws {
        let json: [String: Any] = [
            "choices": [
                [
                    "message": ["role": "assistant", "content": "Truncated..."],
                    "finish_reason": "length",
                ] as [String: Any]
            ],
        ]
        let data = try JSONSerialization.data(withJSONObject: json)

        let response = try OpenAIClient.parseResponse(data: data)
        #expect(response.stopReason == .maxTokens)
    }
}
