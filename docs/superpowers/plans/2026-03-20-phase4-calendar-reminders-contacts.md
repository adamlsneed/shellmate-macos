# Phase 4: Calendar, Reminders, Contacts — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add 3 new providers (Calendar, Reminders, Contacts) with 15 tools total, using EventKit and Contacts frameworks. Wire the PermissionManager to actually check and request macOS permissions. Add Info.plist usage descriptions.

**Architecture:** CalendarProvider and RemindersProvider use `EKEventStore` (EventKit). ContactsProvider uses `CNContactStore` (Contacts framework). All 3 require just-in-time macOS permission prompts — PermissionManager is upgraded from Phase 1 stub to real OS queries. NaturalDateParser handles date input for calendar/reminder tools.

**Tech Stack:** Swift 6.0, macOS 14+, EventKit, Contacts, Swift Testing

**Spec:** `docs/superpowers/specs/2026-03-19-macos-agent-capabilities-design.md` — Phase 4 section

**Baseline:** 335 tests passing, Phase 3 complete (tag: `phase3-enhanced-shell-files-complete`)

---

## File Map

### New Files (Create)

| File | Responsibility |
|---|---|
| `Shellmate/Services/Tools/Calendar/CalendarService.swift` | Shared EKEventStore wrapper for calendar tools |
| `Shellmate/Services/Tools/Calendar/CalendarListEventsTool.swift` | List events in date range |
| `Shellmate/Services/Tools/Calendar/CalendarCreateEventTool.swift` | Create calendar event |
| `Shellmate/Services/Tools/Calendar/CalendarModifyEventTool.swift` | Modify existing event |
| `Shellmate/Services/Tools/Calendar/CalendarDeleteEventTool.swift` | Delete event |
| `Shellmate/Services/Tools/Calendar/CalendarCheckAvailabilityTool.swift` | Check free/busy |
| `Shellmate/Services/Tools/Calendar/CalendarProvider.swift` | Provider for calendar category |
| `Shellmate/Services/Tools/Reminders/RemindersService.swift` | Shared EKEventStore wrapper for reminders |
| `Shellmate/Services/Tools/Reminders/RemindersCreateTool.swift` | Create reminder |
| `Shellmate/Services/Tools/Reminders/RemindersListTool.swift` | List reminders |
| `Shellmate/Services/Tools/Reminders/RemindersCompleteTool.swift` | Mark reminder complete |
| `Shellmate/Services/Tools/Reminders/RemindersModifyTool.swift` | Modify reminder |
| `Shellmate/Services/Tools/Reminders/RemindersDeleteTool.swift` | Delete reminder |
| `Shellmate/Services/Tools/Reminders/RemindersListListsTool.swift` | List reminder lists |
| `Shellmate/Services/Tools/Reminders/RemindersProvider.swift` | Provider for reminders category |
| `Shellmate/Services/Tools/Contacts/ContactsService.swift` | Shared CNContactStore wrapper |
| `Shellmate/Services/Tools/Contacts/ContactsSearchTool.swift` | Search contacts |
| `Shellmate/Services/Tools/Contacts/ContactsGetDetailTool.swift` | Get full contact detail |
| `Shellmate/Services/Tools/Contacts/ContactsCreateTool.swift` | Create new contact |
| `Shellmate/Services/Tools/Contacts/ContactsUpdateTool.swift` | Update contact |
| `Shellmate/Services/Tools/Contacts/ContactsProvider.swift` | Provider for contacts category |
| `ShellmateTests/Tools/Calendar/CalendarToolTests.swift` | Calendar tool tests |
| `ShellmateTests/Tools/Reminders/RemindersToolTests.swift` | Reminders tool tests |
| `ShellmateTests/Tools/Contacts/ContactsToolTests.swift` | Contacts tool tests |

### Modified Files

| File | Changes |
|---|---|
| `Shellmate/Services/Shared/PermissionManager.swift` | Add real EKEventStore/CNContactStore authorization checks |
| `Shellmate/Views/Chat/ChatView.swift` | Register 3 new providers |
| `Info.plist` | Add NSCalendarsFullAccessUsageDescription, NSRemindersFullAccessUsageDescription, NSContactsUsageDescription |

---

## Task 1: Upgrade PermissionManager for Real OS Queries

**Files:**
- Modify: `Shellmate/Services/Shared/PermissionManager.swift`
- Test: `ShellmateTests/Tools/Shared/PermissionManagerTests.swift` (add tests)

The PermissionManager is currently a stub. Upgrade it to actually query EventKit and Contacts authorization status.

- [ ] **Step 1: Add EventKit and Contacts imports and real status checks**

```swift
// In PermissionManager.swift, add:
import EventKit
import Contacts

// Add a method to query real OS authorization:
func queryRealStatus(for permission: SystemPermission) -> PermissionStatus {
    switch permission {
    case .calendars:
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess, .authorized: return .granted
        case .denied: return .denied
        case .restricted: return .restricted
        case .notDetermined, .writeOnly: return .notRequested
        @unknown default: return .notRequested
        }
    case .reminders:
        switch EKEventStore.authorizationStatus(for: .reminder) {
        case .fullAccess, .authorized: return .granted
        case .denied: return .denied
        case .restricted: return .restricted
        case .notDetermined, .writeOnly: return .notRequested
        @unknown default: return .notRequested
        }
    case .contacts:
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .authorized: return .granted
        case .denied: return .denied
        case .restricted: return .restricted
        case .notDetermined: return .notRequested
        @unknown default: return .notRequested
        }
    default:
        return cache[permission, default: .notRequested]
    }
}

// Add a request method:
func requestPermission(_ permission: SystemPermission) async -> PermissionStatus {
    switch permission {
    case .calendars:
        let store = EKEventStore()
        do {
            let granted = try await store.requestFullAccessToEvents()
            let status: PermissionStatus = granted ? .granted : .denied
            cache[permission] = status
            return status
        } catch { return .denied }
    case .reminders:
        let store = EKEventStore()
        do {
            let granted = try await store.requestFullAccessToReminders()
            let status: PermissionStatus = granted ? .granted : .denied
            cache[permission] = status
            return status
        } catch { return .denied }
    case .contacts:
        let store = CNContactStore()
        do {
            let granted = try await store.requestAccess(for: .contacts)
            let status: PermissionStatus = granted ? .granted : .denied
            cache[permission] = status
            return status
        } catch { return .denied }
    default:
        return .notRequested
    }
}
```

- [ ] **Step 2: Update `checkPermissions(for:)` to use real checks for calendar/reminders/contacts providers**

The method currently returns `nil`. Update it to check the tool's category and query real permission status. If permission is `.notRequested`, request it. If `.denied`, return the deniedMessage.

- [ ] **Step 3: Add tests for real permission queries**

Test `queryRealStatus` returns a valid status (we can't control what the OS returns, but we can verify the method runs without error).

- [ ] **Step 4: Add Info.plist usage descriptions**

```xml
<key>NSCalendarsFullAccessUsageDescription</key>
<string>Shellmate needs calendar access to create events, check your schedule, and manage appointments on your behalf.</string>
<key>NSRemindersFullAccessUsageDescription</key>
<string>Shellmate needs reminders access to create, complete, and manage your reminders.</string>
<key>NSContactsUsageDescription</key>
<string>Shellmate needs contacts access to look up contact information and add new contacts on your behalf.</string>
```

- [ ] **Step 5: Commit**

```bash
git add Shellmate/Services/Shared/PermissionManager.swift ShellmateTests/Tools/Shared/ Info.plist
git commit -m "feat: upgrade PermissionManager with real EventKit and Contacts authorization"
```

---

## Task 2: CalendarProvider — 5 calendar tools

**Files:**
- Create: `Shellmate/Services/Tools/Calendar/CalendarService.swift`
- Create: `Shellmate/Services/Tools/Calendar/CalendarListEventsTool.swift`
- Create: `Shellmate/Services/Tools/Calendar/CalendarCreateEventTool.swift`
- Create: `Shellmate/Services/Tools/Calendar/CalendarModifyEventTool.swift`
- Create: `Shellmate/Services/Tools/Calendar/CalendarDeleteEventTool.swift`
- Create: `Shellmate/Services/Tools/Calendar/CalendarCheckAvailabilityTool.swift`
- Create: `Shellmate/Services/Tools/Calendar/CalendarProvider.swift`
- Test: `ShellmateTests/Tools/Calendar/CalendarToolTests.swift`

### CalendarService (shared EKEventStore wrapper)

```swift
actor CalendarService {
    private let store = EKEventStore()

    func events(from start: Date, to end: Date, calendars: [EKCalendar]? = nil) -> [EKEvent]
    func createEvent(title: String, startDate: Date, endDate: Date, calendar: EKCalendar?,
                     location: String?, notes: String?, alerts: [TimeInterval]?) throws -> EKEvent
    func findEvent(matching query: String, near date: Date?) -> EKEvent?
    func modifyEvent(_ event: EKEvent, updates: [String: Any]) throws
    func deleteEvent(_ event: EKEvent) throws
    func calendars() -> [EKCalendar]
    func defaultCalendar() -> EKCalendar?
}
```

### Tool Specs

| Tool | Identifier | Tier | Key Params |
|---|---|---|---|
| CalendarListEventsTool | calendar_list_events | .read | start_date, end_date, calendar_name (opt) |
| CalendarCreateEventTool | calendar_create_event | .write | title, start_date, end_date/duration, calendar_name (opt), location (opt), notes (opt) |
| CalendarModifyEventTool | calendar_modify_event | .write | search_query, updates (title, start, end, location, notes) |
| CalendarDeleteEventTool | calendar_delete_event | .destructive | search_query or event_id |
| CalendarCheckAvailabilityTool | calendar_check_availability | .read | date, duration (opt) |

All calendar tools use `NaturalDateParser` for date parameters. The provider requires `.calendars` permission.

### CalendarProvider

```swift
struct CalendarProvider: ToolProvider {
    let category = ToolCategory.calendar
    let displayName = "Calendar"
    let requiredPermissions: [SystemPermission] = [.calendars]
    private let calendarService: CalendarService
    private let dateParser: NaturalDateParser

    init() {
        self.calendarService = CalendarService()
        self.dateParser = NaturalDateParser()
    }

    var tools: [AgentTool] { /* 5 tools */ }
}
```

### Tests

Since EventKit requires real calendar access (which may not be granted in test environments), tests should:
- Verify tool conformance (identifier, category, tier, parameterSchema)
- Test parameter validation (missing required params → error)
- Test date parsing integration (verify NaturalDateParser is used)
- For create/modify/delete: verify confirmationDescription returns non-empty

- [ ] **Step 1: Write tests**
- [ ] **Step 2: Implement CalendarService**
- [ ] **Step 3: Implement 5 tools**
- [ ] **Step 4: Create CalendarProvider**
- [ ] **Step 5: Run tests, commit**

```bash
git add Shellmate/Services/Tools/Calendar/ ShellmateTests/Tools/Calendar/
git commit -m "feat: add CalendarProvider with 5 calendar tools using EventKit"
```

---

## Task 3: RemindersProvider — 6 reminders tools

**Files:**
- Create: `Shellmate/Services/Tools/Reminders/RemindersService.swift`
- Create: 5 tool files + RemindersListListsTool + RemindersProvider
- Test: `ShellmateTests/Tools/Reminders/RemindersToolTests.swift`

### RemindersService (shared EKEventStore wrapper for reminders)

```swift
actor RemindersService {
    private let store = EKEventStore()

    func reminders(in list: EKCalendar?, includeCompleted: Bool) async -> [EKReminder]
    func createReminder(title: String, dueDate: Date?, list: EKCalendar?,
                        priority: Int?, notes: String?) throws -> EKReminder
    func complete(_ reminder: EKReminder) throws
    func modify(_ reminder: EKReminder, updates: [String: Any]) throws
    func delete(_ reminder: EKReminder) throws
    func lists() -> [EKCalendar]
}
```

### Tool Specs

| Tool | Identifier | Tier |
|---|---|---|
| RemindersCreateTool | reminders_create | .write |
| RemindersListTool | reminders_list | .read |
| RemindersCompleteTool | reminders_complete | .write |
| RemindersModifyTool | reminders_modify | .write |
| RemindersDeleteTool | reminders_delete | .destructive |
| RemindersListListsTool | reminders_list_lists | .read |

Provider requires `.reminders` permission. Uses NaturalDateParser for due dates.

- [ ] **Step 1: Write tests**
- [ ] **Step 2: Implement RemindersService + 6 tools + provider**
- [ ] **Step 3: Run tests, commit**

```bash
git add Shellmate/Services/Tools/Reminders/ ShellmateTests/Tools/Reminders/
git commit -m "feat: add RemindersProvider with 6 reminder tools using EventKit"
```

---

## Task 4: ContactsProvider — 4 contacts tools

**Files:**
- Create: `Shellmate/Services/Tools/Contacts/ContactsService.swift`
- Create: 4 tool files + ContactsProvider
- Test: `ShellmateTests/Tools/Contacts/ContactsToolTests.swift`

### ContactsService (shared CNContactStore wrapper)

```swift
actor ContactsService {
    private let store = CNContactStore()

    func search(query: String, limit: Int) throws -> [CNContact]
    func getDetail(identifier: String) throws -> CNContact
    func create(firstName: String, lastName: String?, phones: [String]?,
                emails: [String]?, organization: String?) throws -> CNContact
    func update(identifier: String, updates: [String: Any]) throws
}
```

### Tool Specs

| Tool | Identifier | Tier |
|---|---|---|
| ContactsSearchTool | contacts_search | .read |
| ContactsGetDetailTool | contacts_get_detail | .read |
| ContactsCreateTool | contacts_create | .write |
| ContactsUpdateTool | contacts_update | .write |

Provider requires `.contacts` permission.

- [ ] **Step 1: Write tests**
- [ ] **Step 2: Implement ContactsService + 4 tools + provider**
- [ ] **Step 3: Run tests, commit**

```bash
git add Shellmate/Services/Tools/Contacts/ ShellmateTests/Tools/Contacts/
git commit -m "feat: add ContactsProvider with 4 contact tools using Contacts framework"
```

---

## Task 5: Register Providers + Final Verification

**Files:**
- Modify: `Shellmate/Views/Chat/ChatView.swift`

- [ ] **Step 1: Register 3 new providers in ChatView**

```swift
await registry.register(CalendarProvider())
await registry.register(RemindersProvider())
await registry.register(ContactsProvider())
```

- [ ] **Step 2: Run full test suite**
- [ ] **Step 3: Release build**
- [ ] **Step 4: Commit and tag**

```bash
git add Shellmate/Views/Chat/ChatView.swift
git commit -m "feat: register Calendar, Reminders, Contacts providers"
git tag phase4-calendar-reminders-contacts-complete
```
