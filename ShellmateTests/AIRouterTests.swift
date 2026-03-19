import Testing
@testable import Shellmate

@Suite("AIRouter")
struct AIRouterTests {

    @Test("detects provider from model name")
    func testDetectProvider() {
        #expect(detectProvider(model: "claude-sonnet-4-20250514") == .anthropic)
        #expect(detectProvider(model: "claude-3-haiku") == .anthropic)
        #expect(detectProvider(model: "gpt-4o") == .openai)
        #expect(detectProvider(model: "o1-preview") == .openai)
        #expect(detectProvider(model: "o3-mini") == .openai)
    }

    @Test("normalizes model by stripping provider prefix")
    func testNormalizeModel() {
        #expect(normalizeModel("anthropic/claude-sonnet-4-20250514") == "claude-sonnet-4-20250514")
        #expect(normalizeModel("openai/gpt-4o") == "gpt-4o")
        #expect(normalizeModel("claude-3-haiku") == "claude-3-haiku")
    }

    @Test("detects OAuth tokens")
    func testIsOAuthToken() {
        #expect(isOAuthToken("sk-ant-oat-abc123"))
        #expect(!isOAuthToken("sk-ant-api-abc123"))
        #expect(!isOAuthToken("sk-proj-abc123"))
    }

    @Test("tool deny categories map correctly")
    func testToolDenyCategories() {
        #expect(ToolDenyCategory.exec.blockedTools == ["shell_exec"])
        #expect(ToolDenyCategory.write.blockedTools == ["file_write"])
        #expect(ToolDenyCategory.read.blockedTools == ["file_read", "file_list"])
        #expect(ToolDenyCategory.web.blockedTools == ["web_search", "web_fetch"])
        #expect(ToolDenyCategory.browser.blockedTools == ["web_fetch"])
    }

    @Test("deny categories filter inline tool arrays")
    func testToolFiltering() {
        let all: [ToolDefinition] = [
            ToolDefinition(name: "shell_exec", description: "Shell", inputSchema: ToolInputSchema(type: "object", properties: [:], required: [])),
            ToolDefinition(name: "file_read", description: "Read", inputSchema: ToolInputSchema(type: "object", properties: [:], required: [])),
            ToolDefinition(name: "file_write", description: "Write", inputSchema: ToolInputSchema(type: "object", properties: [:], required: [])),
            ToolDefinition(name: "file_list", description: "List", inputSchema: ToolInputSchema(type: "object", properties: [:], required: [])),
            ToolDefinition(name: "web_search", description: "Search", inputSchema: ToolInputSchema(type: "object", properties: [:], required: [])),
            ToolDefinition(name: "web_fetch", description: "Fetch", inputSchema: ToolInputSchema(type: "object", properties: [:], required: [])),
        ]
        #expect(all.count == 6)

        let blockedExec = Set(ToolDenyCategory.exec.blockedTools)
        let withoutExec = all.filter { !blockedExec.contains($0.name) }
        #expect(withoutExec.count == 5)
        #expect(!withoutExec.contains(where: { $0.name == "shell_exec" }))

        let blockedWeb = Set(ToolDenyCategory.web.blockedTools)
        let withoutWeb = all.filter { !blockedWeb.contains($0.name) }
        #expect(withoutWeb.count == 4)
    }
}
