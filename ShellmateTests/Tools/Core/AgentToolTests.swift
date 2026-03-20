import Testing
import Foundation
@testable import Shellmate

@Suite("AgentToolResult")
struct AgentToolResultTests {
    @Test("success factory")
    func successFactory() {
        let result = AgentToolResult.success("done")
        #expect(result.content == "done")
        #expect(!result.isError)
        #expect(result.metadata.isEmpty)
    }

    @Test("success with metadata")
    func successWithMetadata() {
        let result = AgentToolResult.success("created", metadata: ["path": "/tmp/test.txt"])
        #expect(result.metadata["path"] == "/tmp/test.txt")
    }

    @Test("error factory")
    func errorFactory() {
        let result = AgentToolResult.error("something broke")
        #expect(result.content == "something broke")
        #expect(result.isError)
    }
}

@Suite("ActionTier")
struct ActionTierTests {
    @Test("all tiers exist")
    func allTiers() {
        let _: ActionTier = .read
        let _: ActionTier = .write
        let _: ActionTier = .destructive
    }
}

@Suite("ToolCategory")
struct ToolCategoryTests {
    @Test("all cases")
    func allCases() {
        #expect(ToolCategory.allCases.count >= 17)
        #expect(ToolCategory.allCases.contains(.shell))
        #expect(ToolCategory.allCases.contains(.calendar))
    }

    @Test("raw values are strings")
    func rawValues() {
        #expect(ToolCategory.shell.rawValue == "shell")
        #expect(ToolCategory.files.rawValue == "files")
    }
}

@Suite("SystemPermission")
struct SystemPermissionTests {
    @Test("pre-prompt messages are non-empty")
    func prePromptMessages() {
        for perm in SystemPermission.allCases {
            #expect(!perm.prePromptMessage.isEmpty)
            #expect(!perm.deniedMessage.isEmpty)
        }
    }
}
