import EventKit
import Foundation

// MARK: - CalendarListEventsTool

/// Lists calendar events within a date range.
struct CalendarListEventsTool: AgentTool {
    let identifier = "calendar_list_events"
    let toolDescription = "List calendar events within a date range. Supports natural language dates like 'today', 'tomorrow', 'next Monday', or ISO 8601 format."
    let category = ToolCategory.calendar
    let actionTier = ActionTier.read
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "start_date": ToolProperty(
                type: "string",
                description: "Start date/time for the range (e.g. 'today', 'tomorrow morning', '2026-03-25')."
            ),
            "end_date": ToolProperty(
                type: "string",
                description: "End date/time for the range (e.g. 'tomorrow', 'next Friday', '2026-03-30')."
            ),
            "calendar_name": ToolProperty(
                type: "string",
                description: "Optional calendar name to filter events by."
            ),
        ],
        required: ["start_date", "end_date"]
    )

    private let service: CalendarService
    private let dateParser: NaturalDateParser

    init(service: CalendarService, dateParser: NaturalDateParser = NaturalDateParser()) {
        self.service = service
        self.dateParser = dateParser
    }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        guard let startText = parameters["start_date"] as? String else {
            return .error("Missing required parameter: start_date")
        }
        guard let endText = parameters["end_date"] as? String else {
            return .error("Missing required parameter: end_date")
        }
        guard let startParsed = dateParser.parseDate(startText) else {
            return .error("Could not parse start_date: '\(startText)'. Try a format like 'today', 'tomorrow', or '2026-03-25'.")
        }
        guard let endParsed = dateParser.parseDate(endText) else {
            return .error("Could not parse end_date: '\(endText)'. Try a format like 'tomorrow', 'next Friday', or '2026-03-30'.")
        }

        let calendarName = parameters["calendar_name"] as? String

        do {
            let events = try await service.events(from: startParsed.date, to: endParsed.date, calendarName: calendarName)
            if events.isEmpty {
                return .success("No events found between \(formatDate(startParsed.date)) and \(formatDate(endParsed.date)).")
            }
            let lines = events.map { formatEvent($0) }
            return .success("Found \(events.count) event(s):\n\n" + lines.joined(separator: "\n"))
        } catch {
            return .error(error.localizedDescription)
        }
    }

    private func formatEvent(_ event: EKEvent) -> String {
        let title = event.title ?? "Untitled"
        let start = formatDateTime(event.startDate)
        let end = formatDateTime(event.endDate)
        var line = "• \(title) — \(start) to \(end)"
        if let location = event.location, !location.isEmpty {
            line += " @ \(location)"
        }
        if let calendar = event.calendar?.title {
            line += " [\(calendar)]"
        }
        return line
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
