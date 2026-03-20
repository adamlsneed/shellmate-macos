import EventKit
import Foundation

// MARK: - CalendarCheckAvailabilityTool

/// Checks free/busy time blocks for a given date.
struct CalendarCheckAvailabilityTool: AgentTool {
    let identifier = "calendar_check_availability"
    let toolDescription = "Check your availability for a given date. Returns free and busy time blocks so you can find open slots."
    let category = ToolCategory.calendar
    let actionTier = ActionTier.read
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "date": ToolProperty(
                type: "string",
                description: "The date to check availability for (e.g. 'today', 'tomorrow', '2026-03-25')."
            ),
            "duration": ToolProperty(
                type: "string",
                description: "Minimum free block duration to highlight (e.g. '1 hour', '30 minutes'). Defaults to 1 hour."
            ),
        ],
        required: ["date"]
    )

    private let service: CalendarService
    private let dateParser: NaturalDateParser

    init(service: CalendarService, dateParser: NaturalDateParser = NaturalDateParser()) {
        self.service = service
        self.dateParser = dateParser
    }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        guard let dateText = parameters["date"] as? String else {
            return .error("Missing required parameter: date")
        }
        guard let parsed = dateParser.parseDate(dateText) else {
            return .error("Could not parse date: '\(dateText)'.")
        }

        let durationText = parameters["duration"] as? String ?? "1 hour"
        let minDuration = dateParser.parseDuration(durationText)?.interval ?? 3600

        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: parsed.date)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            return .error("Could not compute end of day.")
        }

        // Working hours: 8 AM to 6 PM
        guard let workStart = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: dayStart),
              let workEnd = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: dayStart) else {
            return .error("Could not compute working hours.")
        }

        do {
            let events = try await service.events(from: dayStart, to: dayEnd, calendarName: nil)
            let formatter = DateFormatter()
            formatter.dateStyle = .none
            formatter.timeStyle = .short

            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .none

            var lines: [String] = []
            lines.append("Availability for \(dateFormatter.string(from: dayStart)):")
            lines.append("")

            // Show busy blocks
            let sorted = events.sorted { $0.startDate < $1.startDate }
            if sorted.isEmpty {
                lines.append("No events scheduled — fully available.")
            } else {
                lines.append("Busy:")
                for event in sorted {
                    let title = event.title ?? "Untitled"
                    lines.append("  • \(formatter.string(from: event.startDate)) – \(formatter.string(from: event.endDate)): \(title)")
                }

                // Compute free blocks during working hours
                lines.append("")
                lines.append("Free blocks (working hours 8 AM – 6 PM, ≥\(formatDuration(minDuration))):")
                let freeBlocks = computeFreeBlocks(
                    events: sorted,
                    rangeStart: workStart,
                    rangeEnd: workEnd,
                    minDuration: minDuration
                )
                if freeBlocks.isEmpty {
                    lines.append("  No free blocks of sufficient duration.")
                } else {
                    for (start, end) in freeBlocks {
                        let dur = end.timeIntervalSince(start)
                        lines.append("  • \(formatter.string(from: start)) – \(formatter.string(from: end)) (\(formatDuration(dur)))")
                    }
                }
            }

            return .success(lines.joined(separator: "\n"))
        } catch {
            return .error(error.localizedDescription)
        }
    }

    private func computeFreeBlocks(
        events: [EKEvent],
        rangeStart: Date,
        rangeEnd: Date,
        minDuration: TimeInterval
    ) -> [(Date, Date)] {
        var freeBlocks: [(Date, Date)] = []
        var cursor = rangeStart

        for event in events {
            let eventStart = max(event.startDate, rangeStart)
            let eventEnd = min(event.endDate, rangeEnd)

            if eventStart > cursor {
                let gap = eventStart.timeIntervalSince(cursor)
                if gap >= minDuration {
                    freeBlocks.append((cursor, eventStart))
                }
            }
            cursor = max(cursor, eventEnd)
        }

        // Check remaining time after last event
        if cursor < rangeEnd {
            let gap = rangeEnd.timeIntervalSince(cursor)
            if gap >= minDuration {
                freeBlocks.append((cursor, rangeEnd))
            }
        }

        return freeBlocks
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }
}
