import Foundation
import Testing
@testable import Shellmate

@Suite("StreamEvent parsing")
struct StreamingParserTests {

    // MARK: - Anthropic Stream Event Parsing

    @Test("parses Anthropic text_delta event")
    func testAnthropicTextDelta() throws {
        // Simulates the JSON that would be extracted from an SSE "data:" line
        let json: [String: Any] = [
            "type": "content_block_delta",
            "index": 0,
            "delta": [
                "type": "text_delta",
                "text": "Hello ",
            ],
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let parsed = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        let type = parsed["type"] as? String
        #expect(type == "content_block_delta")

        let delta = parsed["delta"] as? [String: Any]
        let deltaType = delta?["type"] as? String
        #expect(deltaType == "text_delta")
        #expect(delta?["text"] as? String == "Hello ")
    }

    @Test("parses Anthropic tool_use content_block_start")
    func testAnthropicToolUseStart() throws {
        let json: [String: Any] = [
            "type": "content_block_start",
            "index": 1,
            "content_block": [
                "type": "tool_use",
                "id": "toolu_abc123",
                "name": "shell_exec",
            ],
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let parsed = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        let contentBlock = parsed["content_block"] as? [String: Any]
        #expect(contentBlock?["type"] as? String == "tool_use")
        #expect(contentBlock?["id"] as? String == "toolu_abc123")
        #expect(contentBlock?["name"] as? String == "shell_exec")
    }

    @Test("parses Anthropic input_json_delta")
    func testAnthropicInputJsonDelta() throws {
        let json: [String: Any] = [
            "type": "content_block_delta",
            "index": 1,
            "delta": [
                "type": "input_json_delta",
                "partial_json": "{\"comma",
            ],
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let parsed = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        let delta = parsed["delta"] as? [String: Any]
        #expect(delta?["type"] as? String == "input_json_delta")
        #expect(delta?["partial_json"] as? String == "{\"comma")
    }

    @Test("parses Anthropic message_delta with stop_reason")
    func testAnthropicMessageDelta() throws {
        let json: [String: Any] = [
            "type": "message_delta",
            "delta": [
                "stop_reason": "tool_use",
            ],
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let parsed = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        let delta = parsed["delta"] as? [String: Any]
        let stopReason = delta?["stop_reason"] as? String
        #expect(StopReason(rawValue: stopReason!) == .toolUse)
    }

    // MARK: - OpenAI Stream Event Parsing

    @Test("parses OpenAI text content delta")
    func testOpenAITextDelta() throws {
        let json: [String: Any] = [
            "choices": [
                [
                    "delta": ["content": "Hello "],
                    "index": 0,
                ] as [String: Any]
            ]
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let parsed = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        let choices = parsed["choices"] as? [[String: Any]]
        let delta = choices?[0]["delta"] as? [String: Any]
        #expect(delta?["content"] as? String == "Hello ")
    }

    @Test("parses OpenAI tool_call start with id and name")
    func testOpenAIToolCallStart() throws {
        let json: [String: Any] = [
            "choices": [
                [
                    "delta": [
                        "tool_calls": [
                            [
                                "index": 0,
                                "id": "call_xyz789",
                                "type": "function",
                                "function": [
                                    "name": "web_search",
                                    "arguments": "",
                                ],
                            ] as [String: Any]
                        ]
                    ] as [String: Any],
                    "index": 0,
                ] as [String: Any]
            ]
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let parsed = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        let choices = parsed["choices"] as? [[String: Any]]
        let delta = choices?[0]["delta"] as? [String: Any]
        let toolCalls = delta?["tool_calls"] as? [[String: Any]]
        #expect(toolCalls?.count == 1)
        #expect(toolCalls?[0]["id"] as? String == "call_xyz789")
        let fn = toolCalls?[0]["function"] as? [String: Any]
        #expect(fn?["name"] as? String == "web_search")
    }

    @Test("parses OpenAI tool_call incremental arguments")
    func testOpenAIToolCallArgsDelta() throws {
        // Subsequent chunks only have index + function.arguments (no id)
        let json: [String: Any] = [
            "choices": [
                [
                    "delta": [
                        "tool_calls": [
                            [
                                "index": 0,
                                "function": [
                                    "arguments": "nd\":\"ls",
                                ],
                            ] as [String: Any]
                        ]
                    ] as [String: Any],
                    "index": 0,
                ] as [String: Any]
            ]
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let parsed = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        let choices = parsed["choices"] as? [[String: Any]]
        let delta = choices?[0]["delta"] as? [String: Any]
        let toolCalls = delta?["tool_calls"] as? [[String: Any]]
        // No id on subsequent chunks
        #expect(toolCalls?[0]["id"] == nil)
        let fn = toolCalls?[0]["function"] as? [String: Any]
        #expect(fn?["arguments"] as? String == "nd\":\"ls")
    }

    @Test("parses OpenAI finish_reason tool_calls")
    func testOpenAIFinishReasonToolCalls() throws {
        let json: [String: Any] = [
            "choices": [
                [
                    "delta": [:] as [String: Any],
                    "index": 0,
                    "finish_reason": "tool_calls",
                ] as [String: Any]
            ]
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let parsed = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        let choices = parsed["choices"] as? [[String: Any]]
        let finishReason = choices?[0]["finish_reason"] as? String
        #expect(finishReason == "tool_calls")
    }
}
