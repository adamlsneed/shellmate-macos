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

    @Test("tool filtering respects deny categories")
    func testToolFiltering() {
        let all = ToolDefinitions.all
        #expect(all.count == 6)

        let withoutExec = ToolDefinitions.available(denyCategories: [.exec])
        #expect(withoutExec.count == 5)
        #expect(!withoutExec.contains(where: { $0.name == "shell_exec" }))

        let withoutWeb = ToolDefinitions.available(denyCategories: [.web])
        #expect(withoutWeb.count == 4)
    }
}
