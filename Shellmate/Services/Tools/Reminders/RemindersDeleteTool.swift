import EventKit
import Foundation

// MARK: - RemindersDeleteTool

/// Deletes a reminder found by search query.
struct RemindersDeleteTool: AgentTool {
    let identifier = "reminders_delete"
    let toolDescription = "Delete a reminder. Searches by title to find and remove it."
    let category = ToolCategory.reminders
    let actionTier = ActionTier.destructive
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
            let title = try await service.deleteReminder(query: query)
            return .success("Deleted reminder '\(title)'.")
        } catch {
            return .error(error.localizedDescription)
        }
    }

    func confirmationDescription(parameters: [String: Any]) -> String {
        let query = parameters["search_query"] as? String ?? "reminder"
        return "Delete reminder matching '\(query)'"
    }

    func confirmationDescription(parameters: [String: Any]) async -> String? {
        guard let query = parameters["search_query"] as? String else { return nil }
        guard let info = await service.reminderInfo(matching: query) else { return nil }
        if let due = info.dueDate {
            return "Delete reminder '\(info.title)' (due \(Self.dateFormatter.string(from: due)))"
        }
        return "Delete reminder '\(info.title)'"
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()
}
