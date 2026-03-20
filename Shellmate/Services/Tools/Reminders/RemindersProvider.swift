import Foundation

// MARK: - RemindersProvider

/// Provides reminder tools to the agent tool registry.
struct RemindersProvider: ToolProvider {
    let category = ToolCategory.reminders
    let displayName = "Reminders"
    let requiredPermissions: [SystemPermission] = [.reminders]

    private let service = RemindersService()
    private let dateParser = NaturalDateParser()

    var tools: [AgentTool] {
        [
            RemindersCreateTool(service: service, dateParser: dateParser),
            RemindersListTool(service: service),
            RemindersCompleteTool(service: service),
            RemindersModifyTool(service: service, dateParser: dateParser),
            RemindersDeleteTool(service: service),
            RemindersListListsTool(service: service),
        ]
    }
}
