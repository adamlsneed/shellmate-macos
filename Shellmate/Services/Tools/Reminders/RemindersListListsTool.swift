import EventKit
import Foundation

// MARK: - RemindersListListsTool

/// Lists all available reminder lists.
struct RemindersListListsTool: AgentTool {
    let identifier = "reminders_list_lists"
    let toolDescription = "List all available reminder lists (e.g. 'Reminders', 'Shopping', 'Work')."
    let category = ToolCategory.reminders
    let actionTier = ActionTier.read
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [:],
        required: []
    )

    private let service: RemindersService

    init(service: RemindersService) {
        self.service = service
    }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        do {
            let lists = try await service.allLists()
            if lists.isEmpty {
                return .success("No reminder lists found.")
            }
            let lines = lists.map { "• \($0.title)" }
            return .success("Reminder lists (\(lists.count)):\n\n" + lines.joined(separator: "\n"))
        } catch {
            return .error(error.localizedDescription)
        }
    }
}
