import Foundation

// MARK: - CalendarCreateEventTool

/// Creates a new calendar event.
struct CalendarCreateEventTool: AgentTool {
    let identifier = "calendar_create_event"
    let toolDescription = "Create a new calendar event. Supports natural language dates and durations. Provide either end_date or duration (e.g. '1 hour', '30 minutes')."
    let category = ToolCategory.calendar
    let actionTier = ActionTier.write
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "title": ToolProperty(
                type: "string",
                description: "The title/name of the event."
            ),
            "start_date": ToolProperty(
                type: "string",
                description: "Start date/time (e.g. 'tomorrow at 2pm', '2026-03-25T14:00:00')."
            ),
            "end_date": ToolProperty(
                type: "string",
                description: "End date/time. Required if duration is not provided."
            ),
            "duration": ToolProperty(
                type: "string",
                description: "Duration of the event (e.g. '1 hour', '30 minutes'). Required if end_date is not provided."
            ),
            "calendar_name": ToolProperty(
                type: "string",
                description: "Calendar to add the event to. Uses default calendar if omitted."
            ),
            "location": ToolProperty(
                type: "string",
                description: "Location of the event."
            ),
            "notes": ToolProperty(
                type: "string",
                description: "Notes or description for the event."
            ),
        ],
        required: ["title", "start_date"]
    )

    private let service: CalendarService
    private let dateParser: NaturalDateParser

    init(service: CalendarService, dateParser: NaturalDateParser = NaturalDateParser()) {
        self.service = service
        self.dateParser = dateParser
    }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        guard let title = parameters["title"] as? String else {
            return .error("Missing required parameter: title")
        }
        guard let startText = parameters["start_date"] as? String else {
            return .error("Missing required parameter: start_date")
        }
        guard let startParsed = dateParser.parseDate(startText) else {
            return .error("Could not parse start_date: '\(startText)'.")
        }

        let endDate: Date
        if let endText = parameters["end_date"] as? String {
            guard let endParsed = dateParser.parseDate(endText) else {
                return .error("Could not parse end_date: '\(endText)'.")
            }
            endDate = endParsed.date
        } else if let durationText = parameters["duration"] as? String {
            guard let duration = dateParser.parseDuration(durationText) else {
                return .error("Could not parse duration: '\(durationText)'. Try '1 hour' or '30 minutes'.")
            }
            endDate = startParsed.date.addingTimeInterval(duration.interval)
        } else {
            // Default to 1 hour
            endDate = startParsed.date.addingTimeInterval(3600)
        }

        let calendarName = parameters["calendar_name"] as? String
        let location = parameters["location"] as? String
        let notes = parameters["notes"] as? String

        do {
            let event = try await service.createEvent(
                title: title,
                startDate: startParsed.date,
                endDate: endDate,
                calendarName: calendarName,
                location: location,
                notes: notes
            )
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            let startStr = formatter.string(from: event.startDate)
            let endStr = formatter.string(from: event.endDate)
            var result = "Created event '\(event.title)' from \(startStr) to \(endStr)"
            if let cal = event.calendarName { result += " in calendar '\(cal)'" }
            result += "."
            return .success(result)
        } catch {
            return .error(error.localizedDescription)
        }
    }

    func confirmationDescription(parameters: [String: Any]) -> String {
        let title = parameters["title"] as? String ?? "Untitled"
        let start = parameters["start_date"] as? String ?? "unknown time"
        return "Create calendar event '\(title)' starting \(start)"
    }
}
