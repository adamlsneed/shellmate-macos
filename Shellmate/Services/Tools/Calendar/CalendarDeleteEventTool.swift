import EventKit
import Foundation

// MARK: - CalendarDeleteEventTool

/// Deletes a calendar event found by search query.
struct CalendarDeleteEventTool: AgentTool {
    let identifier = "calendar_delete_event"
    let toolDescription = "Delete a calendar event. Searches for the event by title and removes it."
    let category = ToolCategory.calendar
    let actionTier = ActionTier.destructive
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "search_query": ToolProperty(
                type: "string",
                description: "Text to search for in event titles to find the event to delete."
            ),
        ],
        required: ["search_query"]
    )

    private let service: CalendarService

    init(service: CalendarService) {
        self.service = service
    }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        guard let query = parameters["search_query"] as? String else {
            return .error("Missing required parameter: search_query")
        }

        do {
            let title = try await service.deleteEvent(query: query)
            return .success("Deleted event '\(title)'.")
        } catch {
            return .error(error.localizedDescription)
        }
    }

    func confirmationDescription(parameters: [String: Any]) -> String {
        let query = parameters["search_query"] as? String ?? "event"
        return "Delete calendar event matching '\(query)'"
    }
}
