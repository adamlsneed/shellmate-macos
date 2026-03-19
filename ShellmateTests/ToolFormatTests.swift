import Foundation
import Testing
@testable import Shellmate

@Suite("Tool Definition Format Conversion")
struct ToolFormatTests {

    private static let shellExec = ToolDefinition(
        name: "shell_exec",
        description: "Execute a shell command on the user's Mac.",
        inputSchema: ToolInputSchema(
            type: "object",
            properties: ["command": ToolProperty(type: "string", description: "The shell command to execute")],
            required: ["command"]
        )
    )

    private static let fileRead = ToolDefinition(
        name: "file_read",
        description: "Read a file.",
        inputSchema: ToolInputSchema(
            type: "object",
            properties: ["path": ToolProperty(type: "string", description: "Path to the file")],
            required: ["path"]
        )
    )

    @Test("Anthropic format has correct structure")
    func testAnthropicFormat() {
        let tools = [Self.shellExec].toAnthropicFormat()

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
        let tools = [Self.shellExec].toOpenAIFormat()

        #expect(tools.count == 1)
        let tool = tools[0]
        #expect(tool["type"] as? String == "function")

        let fn = tool["function"] as? [String: Any]
        #expect(fn?["name"] as? String == "shell_exec")
        #expect(fn?["description"] as? String != nil)

        let params = fn?["parameters"] as? [String: Any]
        #expect(params?["type"] as? String == "object")
    }

    @Test("multiple tools convert correctly for both providers")
    func testMultipleToolsConvert() {
        let allTools = [Self.shellExec, Self.fileRead]

        let anthropicTools = allTools.toAnthropicFormat()
        #expect(anthropicTools.count == 2)

        let openaiTools = allTools.toOpenAIFormat()
        #expect(openaiTools.count == 2)

        let anthropicNames = Set(anthropicTools.compactMap { $0["name"] as? String })
        let openaiNames = Set(openaiTools.compactMap {
            ($0["function"] as? [String: Any])?["name"] as? String
        })

        let expectedNames: Set<String> = ["shell_exec", "file_read"]
        #expect(anthropicNames == expectedNames)
        #expect(openaiNames == expectedNames)
    }

    @Test("empty tools array converts to empty")
    func testEmptyToolsConvert() {
        #expect([ToolDefinition]().toAnthropicFormat().isEmpty)
        #expect([ToolDefinition]().toOpenAIFormat().isEmpty)
    }
}
