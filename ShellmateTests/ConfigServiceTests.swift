import Testing
import Foundation
@testable import Shellmate

@Suite("ConfigService")
struct ConfigServiceTests {

    @Test("ShellmateConfig encodes and decodes round-trip")
    func testConfigRoundTrip() throws {
        var config = ShellmateConfig()
        config.setupComplete = true
        config.version = "1.0"
        config.agents.defaults.model = "claude-sonnet-4-20250514"
        config.agents.list = [
            AgentListEntry(id: "main", name: "Buddy", workspace: "~/.shellmate/workspace", tools: ToolPermissions(deny: ["exec"]))
        ]
        config.capabilities.webSearch = true
        config.capabilities.tools.deny = ["browser"]

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)

        let decoded = try JSONDecoder().decode(ShellmateConfig.self, from: data)
        #expect(decoded.setupComplete == true)
        #expect(decoded.agents.defaults.model == "claude-sonnet-4-20250514")
        #expect(decoded.agents.list.count == 1)
        #expect(decoded.agents.list[0].name == "Buddy")
        #expect(decoded.agents.list[0].tools.deny == ["exec"])
        #expect(decoded.capabilities.tools.deny == ["browser"])
    }

    @Test("AgentSpec encodes with snake_case keys")
    func testAgentSpecCodingKeys() throws {
        let spec = AgentSpec(
            id: "main",
            name: "Helper",
            personality: "Friendly",
            mission: "Help the user",
            macApps: ["Safari", "Finder"],
            useCases: ["Organize files"],
            failure: "Ask for help",
            escalation: "Contact support",
            never: ["Delete system files"]
        )

        let data = try JSONEncoder().encode(spec)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        // Verify snake_case keys
        #expect(json["mac_apps"] != nil)
        #expect(json["use_cases"] != nil)
        #expect(json["macApps"] == nil)
    }
}
