import Foundation
import Testing
@testable import Shellmate

@Suite("Tool Definition Format Conversion")
struct ToolFormatTests {

    @Test("Anthropic format has correct structure")
    func testAnthropicFormat() {
        let tools = ToolDefinitions.toAnthropicFormat([ToolDefinitions.shellExec])

        #expect(tools.count == 1)
        let tool = tools[0]
        #expect(tool["name"] as? String == "shell_exec")
        #expect(tool["description"] as? String != nil)

        let schema = tool["input_schema"] as? [String: Any]
        #expect(schema?["type"] as? String == "object")

        let properties = schema?["properties"] as? [String: Any]
        #expect(properties?["command"] != nil)

        let required = schema?["required"] as? [String]
        #expect(required?.contains("command") == true)
    }

    @Test("OpenAI format wraps in function type")
    func testOpenAIFormat() {
        let tools = ToolDefinitions.toOpenAIFormat([ToolDefinitions.shellExec])

        #expect(tools.count == 1)
        let tool = tools[0]
        #expect(tool["type"] as? String == "function")

        let fn = tool["function"] as? [String: Any]
        #expect(fn?["name"] as? String == "shell_exec")
        #expect(fn?["description"] as? String != nil)

        let params = fn?["parameters"] as? [String: Any]
        #expect(params?["type"] as? String == "object")
    }

    @Test("all tools convert correctly for both providers")
    func testAllToolsConvert() {
        let allTools = ToolDefinitions.all

        let anthropicTools = ToolDefinitions.toAnthropicFormat(allTools)
        #expect(anthropicTools.count == 6)

        let openaiTools = ToolDefinitions.toOpenAIFormat(allTools)
        #expect(openaiTools.count == 6)

        // Verify all tools have names in both formats
        let anthropicNames = Set(anthropicTools.compactMap { $0["name"] as? String })
        let openaiNames = Set(openaiTools.compactMap {
            ($0["function"] as? [String: Any])?["name"] as? String
        })

        let expectedNames: Set<String> = [
            "shell_exec", "file_read", "file_write", "file_list", "web_search", "web_fetch",
        ]
        #expect(anthropicNames == expectedNames)
        #expect(openaiNames == expectedNames)
    }

    @Test("empty tools array converts to empty")
    func testEmptyToolsConvert() {
        #expect(ToolDefinitions.toAnthropicFormat([]).isEmpty)
        #expect(ToolDefinitions.toOpenAIFormat([]).isEmpty)
    }
}
