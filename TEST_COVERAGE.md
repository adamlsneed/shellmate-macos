# Test Coverage Report

## Summary

**Total tests:** 605
**Total suites:** 195
**Framework:** Swift Testing (`import Testing`, `@Test`, `#expect`, `@Suite`)
**All tests pass:** Yes (`swift test` exits 0)

## Tests by Category

| Category | Suites | Approx Tests | Files |
|---|---|---|---|
| **Core Architecture** | 6 | ~30 | AgentToolTests, ToolRegistryTests, CategoryResolverTests |
| **Shell & Files** | 8 | ~60 | ShellServiceTests, ShellEnhancedToolTests, FileToolTests, FilesEnhancedToolTests |
| **Web** | 2 | ~15 | WebToolTests |
| **System & Clipboard** | 4 | ~25 | SystemToolTests, ClipboardToolTests |
| **Display & Audio** | 4 | ~30 | DisplayToolTests, AudioToolTests |
| **Calendar & Reminders** | 4 | ~50 | CalendarToolTests, RemindersToolTests |
| **Contacts** | 2 | ~20 | ContactsToolTests |
| **Apps & Process** | 4 | ~30 | AppsToolTests, ProcessToolTests |
| **Developer** | 2 | ~35 | DeveloperToolTests |
| **Network** | 2 | ~20 | NetworkToolTests |
| **Notes & Email** | 4 | ~30 | NotesToolTests, EmailToolTests |
| **Automation** | 2 | ~25 | AutomationToolTests |
| **Media** | 2 | ~30 | MediaToolTests |
| **TTS & Windows** | 4 | ~30 | TTSToolTests, WindowToolTests |
| **Shared Services** | 8 | ~40 | ConfirmationServiceTests, PermissionManagerTests, NaturalDateParserTests, AppleScriptServiceTests |
| **Security** | 4 | ~25 | SecurityPolicyTests, SecurityPolicyExtendedTests, SecurityAuditTests |
| **Models & Services** | 12 | ~60 | ChatMessageTests, JSONValueTests, ConfigServiceTests, etc. |
| **AI Clients** | 6 | ~30 | AnthropicClientTests, OpenAIClientTests, AIRouterTests, StreamingParserTests |

## What's Tested

- **Every tool:** Conformance (identifier, category, tier, schema), parameter validation, confirmationDescription
- **Security:** Path blocklist, URL blocklist, shell command blocklist, SSRF protection, symlink bypass prevention
- **Core services:** ToolRegistry routing, CategoryResolver keyword matching, ConfirmationService tier logic, PermissionManager state
- **NaturalDateParser:** Relative dates, colloquial times, durations, ISO 8601, failure cases
- **Shell execution:** Output capping, timeout with SIGKILL, blocked commands, history tracking
- **File tools:** CRUD, Trash-only delete, compression, SecurityPolicy integration
- **Process tools:** Protected process blocklist rejection

## What's Not Tested

- **Real EventKit/Contacts operations:** Require macOS permission grants not available in CI
- **Real AppleScript execution:** Requires running apps (Notes, Mail, Music)
- **Window management:** Requires Accessibility permission
- **View layer:** No SwiftUI view tests
- **End-to-end pipeline:** No test that sends a full message through ChatView → ToolUseLoop → tool → response
