import Foundation

// MARK: - CalendarProvider

/// Provides calendar tools to the agent tool registry.
struct CalendarProvider: ToolProvider {
    let category = ToolCategory.calendar
    let displayName = "Calendar"
    let requiredPermissions: [SystemPermission] = [.calendars]

    private let service = CalendarService()
    private let dateParser = NaturalDateParser()

    var tools: [AgentTool] {
        [
            CalendarListEventsTool(service: service, dateParser: dateParser),
            CalendarCreateEventTool(service: service, dateParser: dateParser),
            CalendarModifyEventTool(service: service, dateParser: dateParser),
            CalendarDeleteEventTool(service: service),
            CalendarCheckAvailabilityTool(service: service, dateParser: dateParser),
        ]
    }
}
