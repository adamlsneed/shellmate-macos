# macOS Agent Capabilities — Design Specification

**Date:** 2026-03-19
**Status:** Approved
**Scope:** Full macOS system integration for Shellmate AI agent

---

## 1. Overview

Shellmate is an AI agent for macOS that helps non-technical users interact with their Mac through natural conversation. This spec defines the architecture for adding 80+ system integration tools across 20 capability categories — from calendar management to shell execution, file operations, and system monitoring.

### Target Audience

Non-computer-literate older adults. All UX — confirmations, permission prompts, error messages — must use plain, reassuring language. No jargon. Warn users before macOS system dialogs appear.

### Key Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Build order | Ease of workflow | Fewest dependencies first, each phase unlocks the next |
| Tool architecture | Full protocol refactor | Static enums → protocol-conforming types for scalability |
| Confirmation UX | Minimal friction | Inline chat confirmations, per-category auto-approve |
| Permission flow | Just-in-time | Request when needed with friendly pre-prompt messages |
| Schema filtering | Category-based | Full category summary always, schemas loaded by relevance |
| Settings UI | Minimal viable | Permissions list + category toggles, expand later |
| AppleScript | Deferred | Built in Phase 6 when Notes/Email/Music actually need it |
| Tool organization | Category Providers | Tools grouped into providers that own shared state |

---

## 2. Core Protocols & Types

### AgentTool Protocol

Every macOS capability is implemented as a tool conforming to this protocol:

```swift
protocol AgentTool: Sendable {
    var identifier: String { get }
    var toolDescription: String { get }
    var category: ToolCategory { get }
    var actionTier: ActionTier { get }
    var parameterSchema: ToolInputSchema { get }

    func execute(parameters: [String: Any]) async throws -> ToolResult
}
```

Tools receive `[String: Any]` parameters (conversion from `JSONValue` happens once in the registry). Each tool is responsible for parameter validation and calling `SecurityPolicy` where applicable.

### ToolProvider Protocol

Tools are grouped into providers by category. Each provider owns related tools and their shared state:

```swift
protocol ToolProvider: Sendable {
    var category: ToolCategory { get }
    var displayName: String { get }
    var tools: [AgentTool] { get }
    var requiredPermissions: [SystemPermission] { get }
    var isEnabled: Bool { get }
}
```

### Supporting Types

```swift
enum ToolCategory: String, CaseIterable, Sendable {
    case shell, system, files, clipboard, display, audio, screenshot
    case calendar, reminders, contacts, notes, email
    case apps, web, developer, network
    case automation, media, tts
}

enum ActionTier: Sendable {
    case read        // Execute immediately, no confirmation
    case write       // Inline chat confirmation, auto-approvable per category
    case destructive // Prominent warning, never auto-approved
}

struct ToolResult: Sendable {
    let content: String
    let isError: Bool
    let metadata: [String: String]

    static func success(_ content: String, metadata: [String: String] = [:]) -> ToolResult
    static func error(_ message: String) -> ToolResult
}

enum SystemPermission: String, CaseIterable, Sendable {
    case calendars, reminders, contacts, location
    case microphone, screenCapture, accessibility
    case appleEvents, bluetooth
}
```

---

## 3. ToolRegistry & Category-Based Filtering

### ToolRegistry

Central hub that replaces the current `ToolExecutor` switch statement:

```swift
actor ToolRegistry {
    private var providers: [ToolCategory: ToolProvider] = [:]
    private var toolIndex: [String: AgentTool] = [:]

    func register(_ provider: ToolProvider)
    func unregister(_ category: ToolCategory)

    // Execution — called by ToolExecutor
    func execute(toolName: String, parameters: [String: Any]) async throws -> ToolResult

    // Schema generation — called before each LLM request
    func toolSchemas(for categories: Set<ToolCategory>, denyCategories: [ToolDenyCategory]) -> [ToolDefinition]
    func allToolSchemas() -> [ToolDefinition]

    // Discovery
    func tool(named: String) -> AgentTool?
    func tools(in category: ToolCategory) -> [AgentTool]
    func enabledCategories() -> [ToolCategory]
}
```

### CategoryResolver

Determines which tool categories to include per LLM request via keyword matching:

```swift
struct CategoryResolver {
    func resolve(message: String, enabledCategories: Set<ToolCategory>) -> Set<ToolCategory>
}
```

Static keyword map (e.g., "calendar"/"event"/"schedule" → `.calendar`). Always-included: `.shell` and `.files`. Fallback: if no keywords match, include all enabled categories.

### Refactored ToolExecutor

Thin wrapper delegating to registry + confirmation:

```swift
actor ToolExecutor {
    private let registry: ToolRegistry
    private let confirmationService: ConfirmationService

    func execute(name: String, input: [String: JSONValue]) async -> ToolExecutionResult {
        let anyInput = input.mapValues(\.anyValue)

        guard let tool = await registry.tool(named: name) else {
            return .init(content: "Unknown tool: \(name)", isError: true)
        }

        if tool.actionTier != .read {
            let approved = await confirmationService.confirm(tool: tool, parameters: anyInput)
            if !approved { return .init(content: "Action cancelled by user.", isError: true) }
        }

        let result = try await tool.execute(parameters: anyInput)
        return ToolExecutionResult(content: result.content, isError: result.isError)
    }
}
```

### ToolUseLoop Changes

- Receives `ToolRegistry` via injection (no longer creates its own `ToolExecutor`)
- Gets tool schemas from registry via `CategoryResolver` instead of `ToolDefinitions.available()`
- Round logic unchanged

### Coexistence with ToolDenyCategory

`ToolDenyCategory` (per-agent tool restrictions from config) remains. `ToolCategory` (per-request schema filtering) is a separate concern. `ToolRegistry.toolSchemas(for:denyCategories:)` applies both filters.

---

## 4. ConfirmationService

Bridges actor-isolated tool execution with MainActor UI.

### Flow

```
ToolExecutor.execute()
  → checks ActionTier
  → if .write or .destructive → ConfirmationService.confirm()
  → posts ConfirmationRequest to ChatState
  → UI renders inline confirmation card in chat
  → User taps Approve or Deny
  → CheckedContinuation resumes → execution proceeds or returns "cancelled"
```

### Service

```swift
actor ConfirmationService {
    private var autoApproveCategories: Set<ToolCategory> = []

    func confirm(tool: AgentTool, parameters: [String: Any]) async -> Bool {
        // Auto-approve .write tier if user opted in for this category
        if tool.actionTier == .write && autoApproveCategories.contains(tool.category) {
            return true
        }
        // Destructive tier never auto-approves

        return await requestUserConfirmation(tool: tool, parameters: parameters)
    }

    @MainActor
    private func requestUserConfirmation(tool: AgentTool, parameters: [String: Any]) async -> Bool {
        await withCheckedContinuation { continuation in
            // Posts ConfirmationRequest to ChatState, UI renders card
            // Continuation resumes when user taps Approve/Deny
        }
    }
}
```

### Inline Confirmation UI

Confirmation appears as a chat message card (not a modal — modals are confusing for the target audience):

- **Write tier:** "I'd like to [plain-language description]. [Approve] [Deny]"
- **Destructive tier:** Warning-styled card: "This will [description]. This cannot be easily undone. [Approve] [Deny]"

Each tool provides a `confirmationDescription(parameters:)` method generating the plain-language summary. No raw JSON shown to users.

### Model

```swift
struct ConfirmationRequest: Identifiable, Sendable {
    let id: UUID
    let toolIdentifier: String
    let description: String
    let tier: ActionTier
    let continuation: CheckedContinuation<Bool, Never>
}
```

`ChatState` gains `var pendingConfirmation: ConfirmationRequest?` observed by the chat view.

---

## 5. PermissionManager

Handles macOS system permissions with just-in-time requests and friendly messaging.

### Service

```swift
actor PermissionManager {
    private var cache: [SystemPermission: PermissionStatus] = [:]

    enum PermissionStatus: Sendable {
        case notRequested, granted, denied, restricted
    }

    func status(for permission: SystemPermission) -> PermissionStatus
    func request(_ permission: SystemPermission) async -> (prePromptMessage: String, granted: Bool)
    func allStatuses() -> [SystemPermission: PermissionStatus]

    @MainActor
    func openSettings(for permission: SystemPermission)
}
```

### Pre-prompt Messages

Before triggering any macOS permission dialog, the agent shows a friendly message:

> "To check your schedule, I need to ask macOS for permission to see your calendar. You'll see a popup from macOS in a moment — go ahead and click Allow. This is normal and safe."

Each `SystemPermission` has:
- `prePromptMessage` — shown before the system dialog
- `deniedMessage` — shown when permission was denied, with offer to open System Settings
- `settingsPaneURL` — deep link to the correct System Settings pane

### Integration with Tool Execution

```
ToolRegistry.execute()
  → check PermissionManager.status(for: provider's required permissions)
  → if .notRequested: show prePromptMessage via chat, then request()
  → if .denied: return deniedMessage + offer to open Settings
  → if .granted: proceed to confirmation check → execute
```

Permission check happens before confirmation check.

### Settings Dashboard

Read-only list in Capabilities tab showing each permission's status with "Open Settings" buttons.

---

## 6. ShellService

Replaces the current `ShellTool` static enum. Shared by all CLI-dependent capabilities.

### Service

```swift
actor ShellService {
    private var history: [ShellHistoryEntry] = []  // ring buffer, last 100
    private var environmentCache: [String: String]?

    /// Structured execution — executable + arguments array (no injection risk)
    func run(
        executable: String,
        arguments: [String] = [],
        environment: [String: String]? = nil,
        workingDirectory: URL? = nil,
        timeout: TimeInterval = 300
    ) async throws -> ShellResult

    /// String execution — for LLM-generated command strings
    /// Goes through SecurityPolicy, uses /bin/zsh -c
    func runCommand(
        _ command: String,
        workingDirectory: URL? = nil,
        timeout: TimeInterval = 60
    ) async throws -> ShellResult

    /// Streaming for long-running commands
    func runWithStreaming(
        executable: String,
        arguments: [String],
        onOutput: @Sendable (String) -> Void
    ) async throws -> ShellResult

    /// Resolve executable path
    func which(_ command: String) async -> URL?

    /// Cached shell environment
    func environment() async -> [String: String]

    /// Session history
    func recentHistory(limit: Int = 20) -> [ShellHistoryEntry]
}
```

### Two Execution Paths

- **`runCommand()`** — used only by the `shell_execute` tool (LLM sends command strings). Gated by SecurityPolicy.
- **`run()`** — used by other tools internally (e.g., `app_install` calls `run(executable: "/opt/homebrew/bin/brew", arguments: ["install", "wget"])`). Structured, no injection risk.

### Safety Rules

1. `run()` resolves executable to absolute path via `which()` before execution
2. `runCommand()` checks `SecurityPolicy.isShellCommandBlocked()` first
3. Output capped at 1MB stdout + 1MB stderr
4. Timeout kills entire process tree (SIGTERM → 5s → SIGKILL)
5. Every execution logged to history (command text only, never env vars)
6. All Process launches use `arguments` array, never shell string interpolation

### Supporting Types

```swift
struct ShellResult: Sendable {
    let exitCode: Int32
    let stdout: String
    let stderr: String
    let duration: TimeInterval
    var succeeded: Bool { exitCode == 0 }
}

struct ShellHistoryEntry: Sendable, Identifiable {
    let id: UUID
    let command: String
    let exitCode: Int32
    let timestamp: Date
    let duration: TimeInterval
}
```

---

## 7. NaturalDateParser

Shared utility for Calendar, Reminders, and any time-aware capability.

```swift
struct NaturalDateParser: Sendable {
    struct ParsedDate: Sendable {
        let date: Date
        let hasExplicitTime: Bool
        let source: String
    }

    struct ParsedRange: Sendable {
        let start: Date
        let end: Date
        let source: String
    }

    struct ParsedDuration: Sendable {
        let interval: TimeInterval
        let source: String
    }

    func parseDate(_ text: String, relativeTo: Date = .now) -> ParsedDate?
    func parseRange(_ text: String, relativeTo: Date = .now) -> ParsedRange?
    func parseDuration(_ text: String) -> ParsedDuration?
}
```

### Strategy

1. `NSDataDetector` (`.date` type) first pass — handles most patterns, respects locale
2. Custom regex for relative expressions (`"in \d+ days"`, `"next Tuesday"`)
3. Colloquial time mapping (`"morning"` → 9am, `"afternoon"` → 1pm, `"evening"` → 6pm)
4. All resolution in user's local timezone via `Calendar.current`
5. Ambiguous past dates roll forward

---

## 8. Existing Tool Migration

### Migration Map

| Current | Becomes | Provider |
|---|---|---|
| `ShellTool` (static enum) | `ShellExecuteTool: AgentTool` | `ShellProvider` |
| `FileReadTool` (static enum) | `FileReadTool: AgentTool` | `FilesProvider` |
| `FileWriteTool` (static enum) | `FileWriteTool: AgentTool` | `FilesProvider` |
| `FileListTool` (static enum) | `FileListTool: AgentTool` | `FilesProvider` |
| `WebSearchTool` (static enum) | `WebSearchTool: AgentTool` | `WebProvider` |
| `WebFetchTool` (static enum) | `WebFetchTool: AgentTool` | `WebProvider` |

### Steps

1. Static enums → structs conforming to `AgentTool`
2. Static `execute(input:)` → instance `execute(parameters:)` method
3. Schema data moves from `ToolDefinitions` into each tool (colocation)
4. `ToolDefinitions` enum deleted
5. `ToolExecutor` switch replaced by `ToolRegistry` lookup
6. `ToolUseLoop` gets `ToolRegistry` injected
7. `ToolDenyCategory` stays for per-agent restrictions
8. `toAnthropicFormat()` / `toOpenAIFormat()` move to `ToolRegistry`

### What Doesn't Change

- `ToolInputSchema`, `ToolProperty` structs — reused as-is
- `SecurityPolicy` — untouched
- `AIRouter`, `AnthropicClient`, `OpenAIClient` — untouched
- `ToolUseLoop` round logic — unchanged

### Test Impact

- `ToolExecutorTests` — update to use registry
- `SecurityPolicyTests`, `SecurityAuditTests` — no changes
- `FileToolTests`, `WebToolTests` — update instantiation, same assertions

---

## 9. Settings UI & Config

### Capabilities Tab

- **Permissions list** — each `SystemPermission` with status badge and "Open Settings" button
- **Category toggles** — enable/disable per `ToolCategory`
- **Auto-approve toggles** — per-category for `.write` tier actions

### Config Extension

```swift
struct CapabilitiesConfig: Codable, Sendable {
    // Existing fields preserved
    var webSearch: Bool = true
    var webFetch: Bool = true
    var memory: String = "core"
    var recommendedSkills: [String] = []
    var tools: ToolPermissions = ToolPermissions()

    // New fields
    var enabledCategories: [String] = ToolCategory.allCases.map(\.rawValue)
    var autoApproveCategories: [String] = []
}
```

### Action History

In-memory ring buffer (last 200 actions) logged by `ToolRegistry`. Each entry: timestamp, tool identifier, sanitized parameters summary, result summary, duration. Viewable in settings. Not persisted to disk (privacy-first).

---

## 10. Phase Roadmap

### Phase 1 — Foundation

Everything in this spec: protocols, registry, category resolver, confirmation service, permission manager, ShellService, NaturalDateParser, migration of 6 existing tools into 3 providers, settings UI, config changes.

**Delivers:** Same functionality as today, but on the new architecture. All subsequent phases are additive.

### Phase 2 — System, Clipboard, Display, Audio

| Provider | Tools | Tier | Framework |
|---|---|---|---|
| `SystemProvider` | system_info, system_monitor, system_storage, system_network_info | read | Foundation, IOKit, sysctl |
| `ClipboardProvider` | clipboard_read, clipboard_write, clipboard_clear | read/write | AppKit (NSPasteboard) |
| `DisplayProvider` | display_info, display_brightness, display_dark_mode | read/write | CoreGraphics, IOKit |
| `AudioProvider` | audio_volume, audio_input_output, audio_now_playing, audio_playback_control | read/write | CoreAudio, MediaPlayer |

No macOS permission prompts needed. Minimal new dependencies.

### Phase 3 — Enhanced Shell & Files

| Provider | New Tools | Tier |
|---|---|---|
| `ShellProvider` | shell_script, shell_environment, shell_history, env_check_path, setup_homebrew, setup_developer_tools | varies |
| `FilesProvider` | files_search, files_move, files_copy, files_delete, files_compress, files_decompress, files_disk_usage, files_open, files_reveal_in_finder | varies |

Builds on ShellService and existing file tools. `files_delete` defaults to Trash (never permanent unless confirmed twice).

### Phase 4 — Calendar, Reminders, Contacts

| Provider | Tools | Framework | Permission |
|---|---|---|---|
| `CalendarProvider` | calendar_list_events, calendar_create_event, calendar_modify_event, calendar_delete_event, calendar_check_availability | EventKit | `.calendars` |
| `RemindersProvider` | reminders_create, reminders_list, reminders_complete, reminders_modify, reminders_delete, reminders_list_lists | EventKit | `.reminders` |
| `ContactsProvider` | contacts_search, contacts_get_detail, contacts_create, contacts_update | Contacts | `.contacts` |

First phase requiring macOS permission prompts — exercises the PermissionManager.

### Phase 5 — Apps, Web, Developer, Network

| Provider | Tools |
|---|---|
| `AppsProvider` | app_search, app_install, app_check_installed, app_update, app_uninstall, app_list_installed, app_outdated |
| `ProcessProvider` | process_list, process_kill, app_launch, app_quit, app_running |
| `WebProvider` (expanded) | web_download, app_discover |
| `DeveloperProvider` | git_status, git_log, git_diff, git_commit, git_branch, git_pull, git_push, git_clone, ssh_connect, ssh_config_list, docker_ps, docker_logs, docker_compose, ports_listening, port_kill, env_list, env_set |
| `NetworkProvider` | network_status, wifi_networks, wifi_connect, bluetooth_status, bluetooth_toggle, network_dns_lookup, network_ping, network_port_check, vpn_status |

Heavy use of ShellService for CLI tools (Homebrew, mas, git, docker).

### Phase 6 — Notes, Email, Automation, Media, TTS

| Provider | Tools | Approach |
|---|---|---|
| `AppleScriptService` | (shared service) | Built here when actually needed |
| `NotesProvider` | notes_create, notes_search, notes_read, notes_append, notes_list_folders | AppleScript |
| `EmailProvider` | email_search, email_read, email_compose, email_summarize_unread | Spotlight + AppleScript. **Never auto-send.** |
| `AutomationProvider` | shortcuts_list, shortcuts_run, cron_list, cron_add, cron_remove, launchd_list, launchd_create | Foundation, ShellService |
| `MediaProvider` | music_search, music_play, music_queue, screenshot_capture, image_resize, image_convert, image_ocr, pdf_read, pdf_merge, pdf_split | AppleScript, ScreenCaptureKit, CoreImage, Vision, PDFKit |
| `TTSProvider` | tts_speak, tts_voices | AVFoundation |
| `WindowProvider` | window_list, window_move, window_resize, window_arrange, window_focus | Accessibility API |

---

## 11. File Organization

```
Shellmate/
  Services/
    Tools/
      Core/
        AgentTool.swift              # Protocol
        ToolProvider.swift           # Protocol
        ToolRegistry.swift           # Actor
        CategoryResolver.swift       # Keyword-based filtering
        ToolResult.swift             # Result type
        ActionTier.swift             # Read/Write/Destructive enum
        ToolCategory.swift           # Category enum
      Shell/
        ShellService.swift           # Actor
        ShellExecuteTool.swift
        ShellScriptTool.swift
        ShellEnvironmentTool.swift
        ShellHistoryTool.swift
        ShellProvider.swift
      Files/
        FileReadTool.swift
        FileWriteTool.swift
        FileListTool.swift
        FilesProvider.swift
      Web/
        WebSearchTool.swift
        WebFetchTool.swift
        WebProvider.swift
      Calendar/                      # Phase 4
      Reminders/                     # Phase 4
      Contacts/                      # Phase 4
      System/                        # Phase 2
      Clipboard/                     # Phase 2
      Display/                       # Phase 2
      Audio/                         # Phase 2
      Apps/                          # Phase 5
      Developer/                     # Phase 5
      Network/                       # Phase 5
      Notes/                         # Phase 6
      Email/                         # Phase 6
      Automation/                    # Phase 6
      Media/                         # Phase 6
      TTS/                           # Phase 6
      Windows/                       # Phase 6
      SecurityPolicy.swift           # Unchanged
      ToolExecutor.swift             # Refactored to delegate to ToolRegistry
    Shared/
      ConfirmationService.swift
      PermissionManager.swift
      NaturalDateParser.swift
    AI/                              # Unchanged
    Platform/                        # Unchanged
  Views/
    Settings/
      Capabilities/
        CapabilitiesSettingsView.swift
        PermissionsDashboardView.swift
        CategoryTogglesView.swift
  Models/
    ToolDefinition.swift             # ToolInputSchema, ToolProperty kept; ToolDefinitions enum deleted
    ShellmateConfig.swift            # CapabilitiesConfig extended

ShellmateTests/
  Tools/
    Core/
      ToolRegistryTests.swift
      CategoryResolverTests.swift
      ConfirmationServiceTests.swift
    Shell/
      ShellServiceTests.swift
      ShellProviderTests.swift
    Files/
      FileToolTests.swift            # Migrated
    Web/
      WebToolTests.swift             # Migrated
    Shared/
      NaturalDateParserTests.swift
      PermissionManagerTests.swift
```

---

## 12. Entitlements & Info.plist

Added incrementally as capabilities are built. Phase 1 requires no new entitlements.

### Phase 4 Additions (Calendar, Reminders, Contacts)

**Info.plist:**
```xml
<key>NSCalendarsFullAccessUsageDescription</key>
<string>Shellmate needs calendar access to create events, check your schedule, and manage appointments on your behalf.</string>

<key>NSRemindersFullAccessUsageDescription</key>
<string>Shellmate needs reminders access to create, complete, and manage your reminders.</string>

<key>NSContactsUsageDescription</key>
<string>Shellmate needs contacts access to look up contact information and add new contacts on your behalf.</string>
```

### Phase 6 Additions (Notes, Email, Music, Screenshot, TTS)

**Info.plist:**
```xml
<key>NSAppleEventsUsageDescription</key>
<string>Shellmate needs automation access to interact with Notes, Mail, Music, and other apps on your behalf.</string>

<key>NSMicrophoneUsageDescription</key>
<string>Shellmate needs microphone access for voice dictation and speech recognition.</string>

<key>NSScreenCaptureUsageDescription</key>
<string>Shellmate needs screen capture access to take screenshots when you ask.</string>
```

### Entitlements (already non-sandboxed)

```xml
<key>com.apple.security.personal-information.calendars</key>    <!-- Phase 4 -->
<key>com.apple.security.personal-information.addressbook</key>  <!-- Phase 4 -->
<key>com.apple.security.automation.apple-events</key>           <!-- Phase 6 -->
<key>com.apple.security.device.audio-input</key>                <!-- Phase 6 -->
```

---

## 13. Testing Strategy

### Per Tool
- Parameter validation (missing required, wrong types, boundary values)
- Successful execution with mocked services
- Error handling (permission denied, resource not found, timeout)
- SecurityPolicy integration (blocked paths/commands/URLs)

### Per Provider
- Tool registration and discovery
- Category filtering
- Enable/disable toggling

### Shared Services
- **ConfirmationService:** Write triggers confirmation, denial blocks, auto-approve respects settings
- **PermissionManager:** Status caching, denial handling, pre-prompt messages
- **ShellService:** Blocklist rejection, timeout handling, output capping, history tracking
- **NaturalDateParser:** Extensive suite — relative dates, times, durations, ranges, timezone edge cases, ambiguous inputs
- **CategoryResolver:** Keyword matching, fallback to all, always-included categories

### Integration
- Full tool-use loop with registry (replaces current ToolExecutor tests)
- Permission → confirmation → execution pipeline
- Config persistence round-trip for new CapabilitiesConfig fields
