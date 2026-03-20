import EventKit
import Foundation

// MARK: - RemindersCompleteTool

/// Marks a reminder as completed.
struct RemindersCompleteTool: AgentTool {
    let identifier = "reminders_complete"
    let toolDescription = "Mark a reminder as completed. Searches by title to find the reminder."
    let category = ToolCategory.reminders
    let actionTier = ActionTier.write
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "search_query": ToolProperty(
                type: "string",
                description: "Text to search for in reminder titles."
            ),
        ],
        required: ["search_query"]
    )

    private let service: RemindersService

    init(service: RemindersService) {
        self.service = service
    }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        guard let query = parameters["search_query"] as? String else {
            return .error("Missing required parameter: search_query")
        }

        do {
            let title = try await service.completeReminder(query: query)
            return .success("Marked '\(title)' as completed.")
        } catch {
            return .error(error.localizedDescription)
        }
    }

    func confirmationDescription(parameters: [String: Any]) -> String {
        let query = parameters["search_query"] as? String ?? "reminder"
        return "Complete reminder matching '\(query)'"
    }
}
