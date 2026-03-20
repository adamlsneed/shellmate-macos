@preconcurrency import EventKit
import Foundation

// MARK: - CalendarServiceError

enum CalendarServiceError: Error, LocalizedError {
    case accessDenied
    case eventNotFound(String)
    case saveFailed(String)
    case deleteFailed(String)
    case noDefaultCalendar

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            "Calendar access is not granted. Please allow calendar access in System Settings."
        case .eventNotFound(let query):
            "No event found matching '\(query)'."
        case .saveFailed(let reason):
            "Failed to save event: \(reason)"
        case .deleteFailed(let reason):
            "Failed to delete event: \(reason)"
        case .noDefaultCalendar:
            "No default calendar available for new events."
        }
    }
}

// MARK: - CalendarEventInfo

/// Sendable snapshot of an EKEvent for crossing actor boundaries.
struct CalendarEventInfo: Sendable {
    let title: String
    let startDate: Date
    let endDate: Date
    let location: String?
    let calendarName: String?
    let notes: String?
}

// MARK: - CalendarInfo

/// Sendable snapshot of an EKCalendar.
struct CalendarInfo: Sendable {
    let title: String
    let type: String
}

// MARK: - CalendarService

/// Actor wrapping EKEventStore for thread-safe calendar operations.
actor CalendarService {
    private let store = EKEventStore()

    /// Ensures we have full access to calendar events, requesting if needed.
    func ensureAccess() async throws {
        let status = EKEventStore.authorizationStatus(for: .event)
        if status == .notDetermined {
            try await store.requestFullAccessToEvents()
        }
        let updated = EKEventStore.authorizationStatus(for: .event)
        guard updated == .fullAccess else {
            throw CalendarServiceError.accessDenied
        }
    }

    /// Fetches events in the given date range, optionally filtered by calendar name.
    func events(from start: Date, to end: Date, calendarName: String?) async throws -> [CalendarEventInfo] {
        try await ensureAccess()
        let calendars: [EKCalendar]?
        if let name = calendarName {
            let matched = store.calendars(for: .event).filter {
                $0.title.localizedCaseInsensitiveContains(name)
            }
            calendars = matched.isEmpty ? nil : matched
        } else {
            calendars = nil
        }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: calendars)
        return store.events(matching: predicate).map { snapshot($0) }
    }

    /// Creates a new calendar event and returns a snapshot.
    func createEvent(
        title: String,
        startDate: Date,
        endDate: Date,
        calendarName: String?,
        location: String?,
        notes: String?
    ) async throws -> CalendarEventInfo {
        try await ensureAccess()
        let event = EKEvent(eventStore: store)
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        event.location = location
        event.notes = notes

        if let name = calendarName,
           let cal = store.calendars(for: .event).first(where: {
               $0.title.localizedCaseInsensitiveCompare(name) == .orderedSame
           }) {
            event.calendar = cal
        } else {
            guard let defaultCal = store.defaultCalendarForNewEvents else {
                throw CalendarServiceError.noDefaultCalendar
            }
            event.calendar = defaultCal
        }

        do {
            try store.save(event, span: .thisEvent)
        } catch {
            throw CalendarServiceError.saveFailed(error.localizedDescription)
        }
        return snapshot(event)
    }

    /// Searches for an event matching the query and applies updates.
    func modifyEvent(
        query: String,
        newTitle: String?,
        newStartDate: Date?,
        newEndDate: Date?,
        newLocation: String?,
        newNotes: String?
    ) async throws -> CalendarEventInfo {
        try await ensureAccess()
        let event = try findEvent(matching: query)

        if let t = newTitle { event.title = t }
        if let s = newStartDate { event.startDate = s }
        if let e = newEndDate { event.endDate = e }
        if let l = newLocation { event.location = l }
        if let n = newNotes { event.notes = n }

        do {
            try store.save(event, span: .thisEvent)
        } catch {
            throw CalendarServiceError.saveFailed(error.localizedDescription)
        }
        return snapshot(event)
    }

    /// Searches for and deletes an event matching the query.
    func deleteEvent(query: String) async throws -> String {
        try await ensureAccess()
        let event = try findEvent(matching: query)
        let title = event.title ?? "Untitled"
        do {
            try store.remove(event, span: .thisEvent)
        } catch {
            throw CalendarServiceError.deleteFailed(error.localizedDescription)
        }
        return title
    }

    /// Returns all user-visible calendars for events.
    func allCalendars() async throws -> [CalendarInfo] {
        try await ensureAccess()
        return store.calendars(for: .event).map {
            CalendarInfo(title: $0.title, type: $0.type.rawValue == 0 ? "local" : "calDAV")
        }
    }

    // MARK: - Private

    private func snapshot(_ event: EKEvent) -> CalendarEventInfo {
        CalendarEventInfo(
            title: event.title ?? "Untitled",
            startDate: event.startDate,
            endDate: event.endDate,
            location: event.location,
            calendarName: event.calendar?.title,
            notes: event.notes
        )
    }

    private func findEvent(matching query: String) throws -> EKEvent {
        let now = Date()
        let calendar = Calendar.current
        guard let start = calendar.date(byAdding: .month, value: -6, to: now),
              let end = calendar.date(byAdding: .month, value: 6, to: now) else {
            throw CalendarServiceError.eventNotFound(query)
        }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        let events = store.events(matching: predicate)

        let lowered = query.lowercased()
        guard let found = events.first(where: {
            $0.title?.lowercased().contains(lowered) == true
        }) else {
            throw CalendarServiceError.eventNotFound(query)
        }
        return found
    }
}
