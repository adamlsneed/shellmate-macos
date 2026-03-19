import Foundation

/// Full schema for `~/.shellmate/shellmate.json`.
/// Only fields we manage are decoded; unknown keys are preserved via `additionalData`.
struct ShellmateConfig: Codable, Sendable {
    var version: String = "1.0"
    var setupComplete: Bool = false
    var agents: AgentsConfig = AgentsConfig()
    var capabilities: CapabilitiesConfig = CapabilitiesConfig()

    enum CodingKeys: String, CodingKey {
        case version, setupComplete, agents, capabilities
    }
}

struct AgentsConfig: Codable, Sendable {
    var defaults: AgentDefaults = AgentDefaults()
    var list: [AgentListEntry] = []
}

struct AgentDefaults: Codable, Sendable {
    var model: String = "claude-sonnet-4-20250514"
    var provider: String = "anthropic"
}

struct AgentListEntry: Codable, Sendable, Identifiable {
    var id: String = "main"
    var name: String = ""
    var workspace: String = ""
    var tools: ToolPermissions = ToolPermissions()
}

struct ToolPermissions: Codable, Sendable {
    var deny: [String] = []
}

struct CapabilitiesConfig: Codable, Sendable {
    var webSearch: Bool = true
    var webFetch: Bool = true
    var memory: String = "core"
    var recommendedSkills: [String] = []
    var tools: ToolPermissions = ToolPermissions()
}
