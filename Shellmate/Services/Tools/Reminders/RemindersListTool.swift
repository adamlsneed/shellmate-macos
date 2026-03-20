import EventKit
import Foundation

// MARK: - RemindersListTool

/// Lists reminders, optionally filtered by list name.
struct RemindersListTool: AgentTool {
    let identifier = "reminders_list"
    let toolDescription = "List reminders. Optionally filter by list name and whether to include completed reminders."
    let category = ToolCategory.reminders
    let actionTier = ActionTier.read
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "list_name": ToolProperty(
                type: "string",
                description: "Name of the reminders list to filter by. Shows all lists if omitted."
            ),
            "include_completed": ToolProperty(
                type: "string",
                description: "Whether to include completed reminders. 'true' or 'false'. Defaults to 'false'."
            ),
        ],
        required: []
    )

    private let service: RemindersService

    init(service: RemindersService) {
        self.service = service
    }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        let listName = parameters["list_name"] as? String
        let includeCompleted = (parameters["include_completed"] as? String)?.lowercased() == "true"

        do {
            let reminders = try await service.reminders(inList: listName, includeCompleted: includeCompleted)
            if reminders.isEmpty {
                let scope = listName.map { "in '\($0)'" } ?? ""
                return .success("No \(includeCompleted ? "" : "incomplete ")reminders found\(scope.isEmpty ? "" : " \(scope)").")
            }
            let lines = reminders.map { formatReminder($0) }
            return .success("Found \(reminders.count) reminder(s):\n\n" + lines.joined(separator: "\n"))
        } catch {
            return .error(error.localizedDescription)
        }
    }

    private func formatReminder(_ reminder: EKReminder) -> String {
        let title = reminder.title ?? "Untitled"
        let status = reminder.isCompleted ? "[done]" : "[  ]"
        var line = "\(status) \(title)"
        if let due = reminder.dueDateComponents,
           let date = Calendar.current.date(from: due) {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            line += " — due \(formatter.string(from: date))"
        }
        if reminder.priority > 0 {
            let label = switch reminder.priority {
            case 1...4: "high"
            case 5: "medium"
            default: "low"
            }
            line += " (\(label) priority)"
        }
        if let cal = reminder.calendar?.title {
            line += " [\(cal)]"
        }
        return line
    }
}
