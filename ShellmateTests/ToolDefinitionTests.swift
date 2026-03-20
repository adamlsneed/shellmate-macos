import Testing; import Foundation; @testable import Shellmate

@Suite("ToolDefinition") struct ToolDefinitionTests {

    private static let sampleTool = ToolDefinition(
        name: "shell_exec",
        description: "Execute a shell command",
        inputSchema: ToolInputSchema(
            type: "object",
            properties: ["command": ToolProperty(type: "string", description: "The command")],
            required: ["command"]
        )
    )

    @Test("deny categories block correct tools") func denyCategories() {
        #expect(ToolDenyCategory.exec.blockedTools == ["shell_exec"])
        #expect(ToolDenyCategory.write.blockedTools == ["file_write"])
        #expect(ToolDenyCategory.read.blockedTools == ["file_read", "file_list"])
        #expect(ToolDenyCategory.web.blockedTools == ["web_search", "web_fetch"])
        #expect(ToolDenyCategory.browser.blockedTools == ["web_fetch"])
    }

    @Test("all deny categories blocks all known tools") func allDenyCategories() {
        let allBlocked = Set(ToolDenyCategory.allCases.flatMap(\.blockedTools))
        #expect(allBlocked.contains("shell_exec"))
        #expect(allBlocked.contains("file_read"))
        #expect(allBlocked.contains("web_search"))
    }

    @Test("Codable round-trip") func codableRoundTrip() throws {
        let data = try JSONEncoder().encode(Self.sampleTool)
        let decoded = try JSONDecoder().decode(ToolDefinition.self, from: data)
        #expect(decoded.name == "shell_exec")
        #expect(decoded.inputSchema.required == ["command"])
        #expect(decoded.inputSchema.properties["command"]?.type == "string")
    }

    @Test("Codable with enum values") func codableWithEnum() throws {
        let tool = ToolDefinition(
            name: "test",
            description: "Test",
            inputSchema: ToolInputSchema(
                type: "object",
                properties: ["mode": ToolProperty(type: "string", description: "Mode", enumValues: ["a", "b"])],
                required: ["mode"]
            )
        )
        let data = try JSONEncoder().encode(tool)
        let decoded = try JSONDecoder().decode(ToolDefinition.self, from: data)
        #expect(decoded.inputSchema.properties["mode"]?.enumValues == ["a", "b"])
    }

    @Test("schemas have expected structure") func schemaStructure() {
        #expect(!Self.sampleTool.description.isEmpty)
        #expect(!Self.sampleTool.inputSchema.required.isEmpty)
        #expect(Self.sampleTool.inputSchema.type == "object")
    }
}
