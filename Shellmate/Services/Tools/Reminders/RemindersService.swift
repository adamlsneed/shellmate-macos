import EventKit
import Foundation

// MARK: - RemindersServiceError

enum RemindersServiceError: Error, LocalizedError {
    case accessDenied
    case reminderNotFound(String)
    case saveFailed(String)
    case deleteFailed(String)
    case noDefaultList
    case fetchFailed

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            "Reminders access is not granted. Please allow reminders access in System Settings."
        case .reminderNotFound(let query):
            "No reminder found matching '\(query)'."
        case .saveFailed(let reason):
            "Failed to save reminder: \(reason)"
        case .deleteFailed(let reason):
            "Failed to delete reminder: \(reason)"
        case .noDefaultList:
            "No default reminders list available."
        case .fetchFailed:
            "Failed to fetch reminders."
        }
    }
}

// MARK: - RemindersService

/// Actor wrapping EKEventStore for thread-safe reminder operations.
actor RemindersService {
    private let store = EKEventStore()

    /// Ensures we have full access to reminders, requesting if needed.
    func ensureAccess() async throws {
        let status = EKEventStore.authorizationStatus(for: .reminder)
        if status == .notDetermined {
            try await store.requestFullAccessToReminders()
        }
        let updated = EKEventStore.authorizationStatus(for: .reminder)
        guard updated == .fullAccess || updated == .authorized else {
            throw RemindersServiceError.accessDenied
        }
    }

    /// Fetches reminders from a specific list (or all lists).
    func reminders(inList listName: String?, includeCompleted: Bool) async throws -> [EKReminder] {
        try await ensureAccess()
        let calendars: [EKCalendar]?
        if let name = listName {
            let matched = store.calendars(for: .reminder).filter {
                $0.title.localizedCaseInsensitiveContains(name)
            }
            calendars = matched.isEmpty ? nil : matched
        } else {
            calendars = nil
        }
        let predicate = store.predicateForReminders(in: calendars)
        let all = try await fetchReminders(matching: predicate)

        if includeCompleted {
            return all
        }
        return all.filter { !$0.isCompleted }
    }

    /// Creates a new reminder.
    func createReminder(
        title: String,
        listName: String?,
        dueDate: Date?,
        priority: Int?,
        notes: String?
    ) async throws -> EKReminder {
        try await ensureAccess()
        let reminder = EKReminder(eventStore: store)
        reminder.title = title
        reminder.notes = notes

        if let due = dueDate {
            let calendar = Calendar.current
            reminder.dueDateComponents = calendar.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: due
            )
        }

        if let p = priority {
            reminder.priority = p
        }

        if let name = listName,
           let list = store.calendars(for: .reminder).first(where: {
               $0.title.localizedCaseInsensitiveCompare(name) == .orderedSame
           }) {
            reminder.calendar = list
        } else {
            guard let defaultList = store.defaultCalendarForNewReminders() else {
                throw RemindersServiceError.noDefaultList
            }
            reminder.calendar = defaultList
        }

        do {
            try store.save(reminder, commit: true)
        } catch {
            throw RemindersServiceError.saveFailed(error.localizedDescription)
        }
        return reminder
    }

    /// Marks a reminder as completed.
    func completeReminder(query: String) async throws -> String {
        try await ensureAccess()
        let reminder = try await findReminder(matching: query)
        reminder.isCompleted = true
        reminder.completionDate = Date()
        do {
            try store.save(reminder, commit: true)
        } catch {
            throw RemindersServiceError.saveFailed(error.localizedDescription)
        }
        return reminder.title ?? "Untitled"
    }

    /// Modifies an existing reminder.
    func modifyReminder(
        query: String,
        newTitle: String?,
        newDueDate: Date?,
        newPriority: Int?,
        newNotes: String?
    ) async throws -> EKReminder {
        try await ensureAccess()
        let reminder = try await findReminder(matching: query)

        if let t = newTitle { reminder.title = t }
        if let d = newDueDate {
            let calendar = Calendar.current
            reminder.dueDateComponents = calendar.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: d
            )
        }
        if let p = newPriority { reminder.priority = p }
        if let n = newNotes { reminder.notes = n }

        do {
            try store.save(reminder, commit: true)
        } catch {
            throw RemindersServiceError.saveFailed(error.localizedDescription)
        }
        return reminder
    }

    /// Deletes a reminder matching the query.
    func deleteReminder(query: String) async throws -> String {
        try await ensureAccess()
        let reminder = try await findReminder(matching: query)
        let title = reminder.title ?? "Untitled"
        do {
            try store.remove(reminder, commit: true)
        } catch {
            throw RemindersServiceError.deleteFailed(error.localizedDescription)
        }
        return title
    }

    /// Returns all reminder lists.
    func allLists() async throws -> [EKCalendar] {
        try await ensureAccess()
        return store.calendars(for: .reminder)
    }

    // MARK: - Private

    /// Wraps the callback-based fetchReminders into async.
    private func fetchReminders(matching predicate: NSPredicate) async throws -> [EKReminder] {
        try await withCheckedThrowingContinuation { continuation in
            store.fetchReminders(matching: predicate) { reminders in
                if let reminders {
                    continuation.resume(returning: reminders)
                } else {
                    continuation.resume(throwing: RemindersServiceError.fetchFailed)
                }
            }
        }
    }

    private func findReminder(matching query: String) async throws -> EKReminder {
        let predicate = store.predicateForReminders(in: nil)
        let all = try await fetchReminders(matching: predicate)
        let lowered = query.lowercased()
        guard let found = all.first(where: {
            $0.title?.lowercased().contains(lowered) == true
        }) else {
            throw RemindersServiceError.reminderNotFound(query)
        }
        return found
    }
}
