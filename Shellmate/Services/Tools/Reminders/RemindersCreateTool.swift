import Foundation

// MARK: - RemindersCreateTool

/// Creates a new reminder.
struct RemindersCreateTool: AgentTool {
    let identifier = "reminders_create"
    let toolDescription = "Create a new reminder with an optional due date, priority, and notes. Supports natural language dates."
    let category = ToolCategory.reminders
    let actionTier = ActionTier.write
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "title": ToolProperty(
                type: "string",
                description: "The title of the reminder."
            ),
            "due_date": ToolProperty(
                type: "string",
                description: "Due date/time (e.g. 'tomorrow at 5pm', 'next Friday', '2026-03-25')."
            ),
            "list_name": ToolProperty(
                type: "string",
                description: "Reminders list to add to. Uses default list if omitted."
            ),
            "priority": ToolProperty(
                type: "string",
                description: "Priority level: 'high' (1), 'medium' (5), or 'low' (9). Defaults to none."
            ),
            "notes": ToolProperty(
                type: "string",
                description: "Additional notes for the reminder."
            ),
        ],
        required: ["title"]
    )

    private let service: RemindersService
    private let dateParser: NaturalDateParser

    init(service: RemindersService, dateParser: NaturalDateParser = NaturalDateParser()) {
        self.service = service
        self.dateParser = dateParser
    }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        guard let title = parameters["title"] as? String else {
            return .error("Missing required parameter: title")
        }

        var dueDate: Date?
        if let dueDateText = parameters["due_date"] as? String {
            guard let parsed = dateParser.parseDate(dueDateText) else {
                return .error("Could not parse due_date: '\(dueDateText)'.")
            }
            dueDate = parsed.date
        }

        let priority: Int? = {
            guard let p = parameters["priority"] as? String else { return nil }
            switch p.lowercased() {
            case "high": return 1
            case "medium": return 5
            case "low": return 9
            default: return nil
            }
        }()

        let listName = parameters["list_name"] as? String
        let notes = parameters["notes"] as? String

        do {
            let reminder = try await service.createReminder(
                title: title,
                listName: listName,
                dueDate: dueDate,
                priority: priority,
                notes: notes
            )
            var result = "Created reminder '\(reminder.title)'"
            if let due = reminder.dueDate {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .short
                result += " due \(formatter.string(from: due))"
            }
            if let list = reminder.listName {
                result += " in list '\(list)'"
            }
            result += "."
            return .success(result)
        } catch {
            return .error(error.localizedDescription)
        }
    }

    func confirmationDescription(parameters: [String: Any]) -> String {
        let title = parameters["title"] as? String ?? "Untitled"
        return "Create reminder '\(title)'"
    }
}
