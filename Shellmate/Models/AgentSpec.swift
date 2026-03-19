import Foundation

/// The personalized agent specification built during wizard setup.
/// Maps to `teamSpec.agent` in the Electron app's Zustand store.
struct AgentSpec: Codable, Sendable {
    var id: String = "main"
    var name: String = ""
    var personality: String = ""
    var mission: String = ""
    var macApps: [String] = []
    var useCases: [String] = []
    var failure: String = ""
    var escalation: String = ""
    var never: [String] = []

    enum CodingKeys: String, CodingKey {
        case id, name, personality, mission
        case macApps = "mac_apps"
        case useCases = "use_cases"
        case failure, escalation, never
    }
}
