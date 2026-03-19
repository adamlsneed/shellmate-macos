import Foundation
@testable import Shellmate
enum TestFixtures {
    static func sampleAgentSpec() -> AgentSpec {
        AgentSpec(id: "main", name: "Buddy", personality: "Warm and patient. Explains things simply.",
            mission: "Help with everyday Mac tasks and questions.",
            macApps: ["Safari", "Notes", "Finder"], useCases: ["Organize files", "Search the web"],
            failure: "Apologize and try a different approach",
            escalation: "Ask the user before doing anything risky",
            never: ["Delete system files", "Share personal information"])
    }
    static let emptyAgentSpec = AgentSpec()
    static func sampleConfig(setupComplete: Bool = true) -> ShellmateConfig {
        var config = ShellmateConfig(); config.setupComplete = setupComplete
        config.agents.list = [AgentListEntry(id: "main", name: "Buddy", workspace: "~/.shellmate/workspace")]
        return config
    }
    static func makeIsolatedConfigService() -> (ConfigService, URL) {
        let tmpDir = makeTempDir(prefix: "shellmate-test")
        return (ConfigService(configDir: tmpDir), tmpDir)
    }
    static func makeTempDir(prefix: String) -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(prefix)-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    static func cleanupTempDir(_ url: URL) { try? FileManager.default.removeItem(at: url) }

    static var complexJSONValue: JSONValue {
        .object([
            "name": .string("test"),
            "count": .int(42),
            "active": .bool(true),
            "tags": .array([.string("a"), .string("b")]),
            "nested": .object(["key": .string("value")]),
            "nothing": .null
        ])
    }
}
