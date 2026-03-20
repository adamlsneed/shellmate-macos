import EventKit
import Foundation

// MARK: - CalendarModifyEventTool

/// Modifies an existing calendar event found by search query.
struct CalendarModifyEventTool: AgentTool {
    let identifier = "calendar_modify_event"
    let toolDescription = "Modify an existing calendar event. Search for the event by title, then provide the fields to update."
    let category = ToolCategory.calendar
    let actionTier = ActionTier.write
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "search_query": ToolProperty(
                type: "string",
                description: "Text to search for in event titles to find the event to modify."
            ),
            "new_title": ToolProperty(
                type: "string",
                description: "New title for the event."
            ),
            "new_start_date": ToolProperty(
                type: "string",
                description: "New start date/time for the event."
            ),
            "new_end_date": ToolProperty(
                type: "string",
                description: "New end date/time for the event."
            ),
            "new_location": ToolProperty(
                type: "string",
                description: "New location for the event."
            ),
            "new_notes": ToolProperty(
                type: "string",
                description: "New notes/description for the event."
            ),
        ],
        required: ["search_query"]
    )

    private let service: CalendarService
    private let dateParser: NaturalDateParser

    init(service: CalendarService, dateParser: NaturalDateParser = NaturalDateParser()) {
        self.service = service
        self.dateParser = dateParser
    }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        guard let query = parameters["search_query"] as? String else {
            return .error("Missing required parameter: search_query")
        }

        let newTitle = parameters["new_title"] as? String
        var newStart: Date?
        var newEnd: Date?

        if let startText = parameters["new_start_date"] as? String {
            guard let parsed = dateParser.parseDate(startText) else {
                return .error("Could not parse new_start_date: '\(startText)'.")
            }
            newStart = parsed.date
        }
        if let endText = parameters["new_end_date"] as? String {
            guard let parsed = dateParser.parseDate(endText) else {
                return .error("Could not parse new_end_date: '\(endText)'.")
            }
            newEnd = parsed.date
        }

        let newLocation = parameters["new_location"] as? String
        let newNotes = parameters["new_notes"] as? String

        do {
            let event = try await service.modifyEvent(
                query: query,
                newTitle: newTitle,
                newStartDate: newStart,
                newEndDate: newEnd,
                newLocation: newLocation,
                newNotes: newNotes
            )
            return .success("Modified event '\(event.title ?? query)' successfully.")
        } catch {
            return .error(error.localizedDescription)
        }
    }

    func confirmationDescription(parameters: [String: Any]) -> String {
        let query = parameters["search_query"] as? String ?? "event"
        return "Modify calendar event matching '\(query)'"
    }
}
