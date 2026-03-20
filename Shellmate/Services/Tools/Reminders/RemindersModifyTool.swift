import Foundation

// MARK: - RemindersModifyTool

/// Modifies an existing reminder found by search query.
struct RemindersModifyTool: AgentTool {
    let identifier = "reminders_modify"
    let toolDescription = "Modify an existing reminder. Search by title, then provide fields to update."
    let category = ToolCategory.reminders
    let actionTier = ActionTier.write
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "search_query": ToolProperty(
                type: "string",
                description: "Text to search for in reminder titles."
            ),
            "new_title": ToolProperty(
                type: "string",
                description: "New title for the reminder."
            ),
            "new_due_date": ToolProperty(
                type: "string",
                description: "New due date/time for the reminder."
            ),
            "new_priority": ToolProperty(
                type: "string",
                description: "New priority: 'high', 'medium', 'low', or 'none'."
            ),
            "new_notes": ToolProperty(
                type: "string",
                description: "New notes for the reminder."
            ),
        ],
        required: ["search_query"]
    )

    private let service: RemindersService
    private let dateParser: NaturalDateParser

    init(service: RemindersService, dateParser: NaturalDateParser = NaturalDateParser()) {
        self.service = service
        self.dateParser = dateParser
    }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        guard let query = parameters["search_query"] as? String else {
            return .error("Missing required parameter: search_query")
        }

        let newTitle = parameters["new_title"] as? String
        var newDueDate: Date?
        if let dueDateText = parameters["new_due_date"] as? String {
            guard let parsed = dateParser.parseDate(dueDateText) else {
                return .error("Could not parse new_due_date: '\(dueDateText)'.")
            }
            newDueDate = parsed.date
        }

        let newPriority: Int? = {
            guard let p = parameters["new_priority"] as? String else { return nil }
            switch p.lowercased() {
            case "high": return 1
            case "medium": return 5
            case "low": return 9
            case "none": return 0
            default: return nil
            }
        }()

        let newNotes = parameters["new_notes"] as? String

        do {
            let reminder = try await service.modifyReminder(
                query: query,
                newTitle: newTitle,
                newDueDate: newDueDate,
                newPriority: newPriority,
                newNotes: newNotes
            )
            return .success("Modified reminder '\(reminder.title)' successfully.")
        } catch {
            return .error(error.localizedDescription)
        }
    }

    func confirmationDescription(parameters: [String: Any]) -> String {
        let query = parameters["search_query"] as? String ?? "reminder"
        return "Modify reminder matching '\(query)'"
    }
}
