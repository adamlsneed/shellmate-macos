# Phase 1: Foundation — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the static-enum tool system with a protocol-based provider architecture, add confirmation and permission infrastructure, build ShellService and NaturalDateParser, and migrate all 6 existing tools — delivering identical functionality on the new architecture.

**Architecture:** Tools conform to `AgentTool` protocol, grouped into `ToolProvider`s by category. A `ToolRegistry` actor replaces the `ToolExecutor` switch statement. `ConfirmationService` + `PermissionManager` gate execution. `ShellService` actor replaces inline Process logic. `CategoryResolver` filters schemas per request.

**Tech Stack:** Swift 6.0, macOS 14+, SwiftUI, Observation framework, Swift Testing

**Spec:** `docs/superpowers/specs/2026-03-19-macos-agent-capabilities-design.md`

---

## File Map

### New Files (Create)

| File | Responsibility |
|---|---|
| `Shellmate/Services/Tools/Core/AgentTool.swift` | `AgentTool` protocol, `ActionTier` enum |
| `Shellmate/Services/Tools/Core/AgentToolResult.swift` | `AgentToolResult` struct with factory methods |
| `Shellmate/Services/Tools/Core/ToolCategory.swift` | `ToolCategory` enum, `SystemPermission` enum |
| `Shellmate/Services/Tools/Core/ToolProvider.swift` | `ToolProvider` protocol |
| `Shellmate/Services/Tools/Core/ToolRegistry.swift` | `ToolRegistry` actor |
| `Shellmate/Services/Tools/Core/CategoryResolver.swift` | Keyword-based category filtering |
| `Shellmate/Services/Tools/Shell/ShellService.swift` | `ShellService` actor |
| `Shellmate/Services/Tools/Shell/ShellExecuteTool.swift` | `shell_exec` tool (migrated) |
| `Shellmate/Services/Tools/Shell/ShellProvider.swift` | Shell category provider |
| `Shellmate/Services/Tools/Files/FilesProvider.swift` | Files category provider |
| `Shellmate/Services/Tools/Web/WebProvider.swift` | Web category provider |
| `Shellmate/Services/Shared/ConfirmationService.swift` | `ConfirmationService` actor + `ConfirmationUIHandler` |
| `Shellmate/Services/Shared/PermissionManager.swift` | `PermissionManager` actor |
| `Shellmate/Services/Shared/NaturalDateParser.swift` | Date/time natural language parsing |
| `Shellmate/Views/Settings/Capabilities/CapabilitiesSettingsView.swift` | Settings tab |
| `Shellmate/Views/Chat/ConfirmationCardView.swift` | Inline confirmation UI |
| `ShellmateTests/Tools/Core/AgentToolTests.swift` | Protocol conformance tests |
| `ShellmateTests/Tools/Core/ToolRegistryTests.swift` | Registry tests |
| `ShellmateTests/Tools/Core/CategoryResolverTests.swift` | Keyword matching tests |
| `ShellmateTests/Tools/Shell/ShellServiceTests.swift` | Shell service tests |
| `ShellmateTests/Tools/Shared/NaturalDateParserTests.swift` | Date parsing tests |
| `ShellmateTests/Tools/Shared/ConfirmationServiceTests.swift` | Confirmation flow tests |
| `ShellmateTests/Tools/Shared/PermissionManagerTests.swift` | Permission state tests |

### Modified Files

| File | Changes |
|---|---|
| `Shellmate/Services/Tools/FileReadTool.swift` | `enum` → `struct: AgentTool`, add protocol properties |
| `Shellmate/Services/Tools/FileWriteTool.swift` | `enum` → `struct: AgentTool`, add protocol properties |
| `Shellmate/Services/Tools/FileListTool.swift` | `enum` → `struct: AgentTool`, add protocol properties |
| `Shellmate/Services/Tools/WebFetchTool.swift` | `enum` → `struct: AgentTool`, add protocol properties |
| `Shellmate/Services/Tools/WebSearchTool.swift` | `enum` → `struct: AgentTool`, add protocol properties |
| `Shellmate/Services/Tools/ToolExecutor.swift` | Delegate to `ToolRegistry`, add permission + confirmation |
| `Shellmate/Services/AI/ToolUseLoop.swift` | Inject `ToolExecutor`, use registry for schemas |
| `Shellmate/Models/ToolDefinition.swift` | Delete `ToolDefinitions` enum, keep schema types + `ToolDenyCategory` + format methods |
| `Shellmate/Models/ShellmateConfig.swift` | Extend `CapabilitiesConfig` with new fields |
| `Shellmate/State/ChatState.swift` | Add `pendingConfirmation` property |
| `Shellmate/Views/Chat/ChatView.swift` | Update `ToolUseLoop` creation to use injected executor |
| `Shellmate/Services/AI/AnthropicClient.swift` | Change `ToolDefinitions.toAnthropicFormat(tools)` → `tools.toAnthropicFormat()` |
| `Shellmate/Services/AI/OpenAIClient.swift` | Change `ToolDefinitions.toOpenAIFormat(tools)` → `tools.toOpenAIFormat()` |
| `ShellmateTests/ToolExecutorTests.swift` | Update to use registry |
| `ShellmateTests/ToolDefinitionTests.swift` | Remove `ToolDefinitions` enum tests, add format tests |
| `ShellmateTests/ToolFormatTests.swift` | Update format calls to array extension syntax |
| `ShellmateTests/AIRouterTests.swift` | Remove `ToolDefinitions.available()` / `.all` references |
| `ShellmateTests/AnthropicClientTests.swift` | Replace `ToolDefinitions.shellExec` with inline definitions |
| `ShellmateTests/OpenAIClientTests.swift` | Replace `ToolDefinitions.webSearch` with inline definitions |
| `ShellmateTests/ShellToolTests.swift` | Replace with `ShellServiceTests` (old file deleted with ShellTool) |
| `ShellmateTests/FileToolTests.swift` | Update from static enum calls to instance method calls |
| `ShellmateTests/WebToolTests.swift` | Update from static enum calls to instance method calls |

### Deleted Files

| File | Reason |
|---|---|
| `Shellmate/Services/Tools/ShellTool.swift` | Replaced by `ShellService` + `ShellExecuteTool` |

---

## Task 1: Core Types — AgentToolResult, ActionTier, ToolCategory

**Files:**
- Create: `Shellmate/Services/Tools/Core/AgentToolResult.swift`
- Create: `Shellmate/Services/Tools/Core/ToolCategory.swift`
- Test: `ShellmateTests/Tools/Core/AgentToolTests.swift`

- [ ] **Step 1: Write tests for AgentToolResult**

```swift
import Testing
import Foundation
@testable import Shellmate

@Suite("AgentToolResult")
struct AgentToolResultTests {
    @Test("success factory")
    func successFactory() {
        let result = AgentToolResult.success("done")
        #expect(result.content == "done")
        #expect(!result.isError)
        #expect(result.metadata.isEmpty)
    }

    @Test("success with metadata")
    func successWithMetadata() {
        let result = AgentToolResult.success("created", metadata: ["path": "/tmp/test.txt"])
        #expect(result.metadata["path"] == "/tmp/test.txt")
    }

    @Test("error factory")
    func errorFactory() {
        let result = AgentToolResult.error("something broke")
        #expect(result.content == "something broke")
        #expect(result.isError)
    }
}

@Suite("ActionTier")
struct ActionTierTests {
    @Test("all tiers exist")
    func allTiers() {
        let _: ActionTier = .read
        let _: ActionTier = .write
        let _: ActionTier = .destructive
    }
}

@Suite("ToolCategory")
struct ToolCategoryTests {
    @Test("all cases")
    func allCases() {
        #expect(ToolCategory.allCases.count >= 17)
        #expect(ToolCategory.allCases.contains(.shell))
        #expect(ToolCategory.allCases.contains(.calendar))
    }

    @Test("raw values are strings")
    func rawValues() {
        #expect(ToolCategory.shell.rawValue == "shell")
        #expect(ToolCategory.files.rawValue == "files")
    }
}

@Suite("SystemPermission")
struct SystemPermissionTests {
    @Test("pre-prompt messages are non-empty")
    func prePromptMessages() {
        for perm in SystemPermission.allCases {
            #expect(!perm.prePromptMessage.isEmpty)
            #expect(!perm.deniedMessage.isEmpty)
        }
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter "AgentToolResult|ActionTier|ToolCategory|SystemPermission" 2>&1 | tail -20`
Expected: Compilation errors — types don't exist yet

- [ ] **Step 3: Implement AgentToolResult**

```swift
// Shellmate/Services/Tools/Core/AgentToolResult.swift
import Foundation

/// Result of executing an AgentTool.
/// Named AgentToolResult to avoid collision with ChatMessage.ToolResult.
struct AgentToolResult: Sendable {
    let content: String
    let isError: Bool
    let metadata: [String: String]

    static func success(_ content: String, metadata: [String: String] = [:]) -> AgentToolResult {
        AgentToolResult(content: content, isError: false, metadata: metadata)
    }

    static func error(_ message: String) -> AgentToolResult {
        AgentToolResult(content: message, isError: true, metadata: [:])
    }
}

/// Action classification for tool confirmation behavior.
enum ActionTier: Sendable {
    case read        // Execute immediately, no confirmation
    case write       // Inline chat confirmation, auto-approvable per category
    case destructive // Prominent warning, never auto-approved
}
```

- [ ] **Step 4: Implement ToolCategory and SystemPermission**

```swift
// Shellmate/Services/Tools/Core/ToolCategory.swift
import Foundation

enum ToolCategory: String, CaseIterable, Sendable, Codable {
    case shell, system, files, clipboard, display, audio, screenshot
    case calendar, reminders, contacts, notes, email
    case apps, web, developer, network
    case automation, media, tts

    var displayName: String {
        switch self {
        case .shell: "Shell & Terminal"
        case .system: "System Info"
        case .files: "Files & Storage"
        case .clipboard: "Clipboard"
        case .display: "Display"
        case .audio: "Audio & Volume"
        case .screenshot: "Screenshots"
        case .calendar: "Calendar"
        case .reminders: "Reminders"
        case .contacts: "Contacts"
        case .notes: "Notes"
        case .email: "Email"
        case .apps: "Applications"
        case .web: "Web & Search"
        case .developer: "Developer Tools"
        case .network: "Network"
        case .automation: "Automation"
        case .media: "Media"
        case .tts: "Text to Speech"
        }
    }
}

enum SystemPermission: String, CaseIterable, Sendable {
    case calendars, reminders, contacts, location
    case microphone, screenCapture, accessibility
    case appleEvents, bluetooth

    var displayName: String {
        switch self {
        case .calendars: "Calendar"
        case .reminders: "Reminders"
        case .contacts: "Contacts"
        case .location: "Location"
        case .microphone: "Microphone"
        case .screenCapture: "Screen Recording"
        case .accessibility: "Accessibility"
        case .appleEvents: "Automation"
        case .bluetooth: "Bluetooth"
        }
    }

    var prePromptMessage: String {
        switch self {
        case .calendars:
            "To check your schedule, I need to ask macOS for permission to see your calendar. You'll see a popup from macOS in a moment — go ahead and click Allow. This is normal and safe."
        case .reminders:
            "To manage your reminders, I need macOS to allow me access. A popup will appear — just click Allow. This is normal and safe."
        case .contacts:
            "To look up that contact, I need macOS to allow me access to your address book. A popup will appear — just click Allow. This is normal and safe."
        case .location:
            "To use location features, macOS needs your permission. You'll see a popup — click Allow if you're comfortable sharing your location."
        case .microphone:
            "To listen to your voice, I need macOS to allow microphone access. A popup will appear — just click Allow. This is normal and safe."
        case .screenCapture:
            "To take a screenshot, macOS needs you to give me screen recording permission. You'll see a popup — click Allow, and you may need to restart the app afterward."
        case .accessibility:
            "To manage windows on your screen, I need accessibility permission. You'll see a popup — click Allow. You may need to go to System Settings to turn it on."
        case .appleEvents:
            "To work with other apps like Notes or Mail, I need automation permission. You'll see a popup — just click Allow. This is normal and safe."
        case .bluetooth:
            "To manage Bluetooth devices, I need Bluetooth access. A popup will appear — just click Allow. This is normal and safe."
        }
    }

    var deniedMessage: String {
        switch self {
        case .calendars:
            "I don't have permission to access your calendar. If you'd like to change this, I can open your System Settings to the right spot."
        case .reminders:
            "I don't have permission to access your reminders. If you'd like to change this, I can open your System Settings to the right spot."
        case .contacts:
            "I don't have permission to access your contacts. If you'd like to change this, I can open your System Settings to the right spot."
        case .location:
            "I don't have permission to access your location. If you'd like to change this, I can open your System Settings to the right spot."
        case .microphone:
            "I don't have permission to use the microphone. If you'd like to change this, I can open your System Settings to the right spot."
        case .screenCapture:
            "I don't have permission to capture the screen. If you'd like to change this, I can open your System Settings to the right spot."
        case .accessibility:
            "I don't have accessibility permission. If you'd like to change this, I can open your System Settings to the right spot."
        case .appleEvents:
            "I don't have permission to control other apps. If you'd like to change this, I can open your System Settings to the right spot."
        case .bluetooth:
            "I don't have permission to access Bluetooth. If you'd like to change this, I can open your System Settings to the right spot."
        }
    }

    var settingsPaneURL: URL {
        switch self {
        case .calendars, .reminders, .contacts:
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")!
        case .location:
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices")!
        case .microphone:
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!
        case .screenCapture:
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
        case .accessibility:
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        case .appleEvents:
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")!
        case .bluetooth:
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Bluetooth")!
        }
    }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `swift test --filter "AgentToolResult|ActionTier|ToolCategory|SystemPermission" 2>&1 | tail -20`
Expected: All tests PASS

- [ ] **Step 6: Commit**

```bash
git add Shellmate/Services/Tools/Core/AgentToolResult.swift Shellmate/Services/Tools/Core/ToolCategory.swift ShellmateTests/Tools/Core/AgentToolTests.swift
git commit -m "feat: add AgentToolResult, ActionTier, ToolCategory, SystemPermission types"
```

---

## Task 2: AgentTool and ToolProvider Protocols

**Files:**
- Create: `Shellmate/Services/Tools/Core/AgentTool.swift`
- Create: `Shellmate/Services/Tools/Core/ToolProvider.swift`

- [ ] **Step 1: Implement AgentTool protocol**

```swift
// Shellmate/Services/Tools/Core/AgentTool.swift
import Foundation

/// Protocol for all macOS agent tools.
/// Each tool represents a single action the agent can perform.
protocol AgentTool: Sendable {
    /// Unique identifier used by the LLM to invoke this tool (e.g., "shell_exec")
    var identifier: String { get }

    /// Human-readable description provided to the LLM so it knows when/how to use this tool
    var toolDescription: String { get }

    /// Which category this tool belongs to (for filtering and settings)
    var category: ToolCategory { get }

    /// Confirmation behavior: read (immediate), write (confirm), destructive (warn+confirm)
    var actionTier: ActionTier { get }

    /// JSON Schema for the parameters this tool accepts
    var parameterSchema: ToolInputSchema { get }

    /// Execute the tool with the given parameters
    func execute(parameters: [String: Any]) async throws -> AgentToolResult

    /// Plain-language description of what this action will do, shown in confirmation cards.
    func confirmationDescription(parameters: [String: Any]) -> String
}

extension AgentTool {
    /// Default implementation for read-tier tools that don't need confirmation.
    func confirmationDescription(parameters: [String: Any]) -> String { "" }

    /// Convert this tool's schema to a ToolDefinition for the AI provider format converters.
    func toToolDefinition() -> ToolDefinition {
        ToolDefinition(
            name: identifier,
            description: toolDescription,
            inputSchema: parameterSchema
        )
    }
}
```

- [ ] **Step 2: Implement ToolProvider protocol**

```swift
// Shellmate/Services/Tools/Core/ToolProvider.swift
import Foundation

/// Groups related tools by category. Each provider owns its tools and their shared state.
protocol ToolProvider: Sendable {
    /// The category this provider covers
    var category: ToolCategory { get }

    /// Display name for settings UI
    var displayName: String { get }

    /// All tools this provider offers
    var tools: [AgentTool] { get }

    /// macOS permissions required by any tool in this provider
    var requiredPermissions: [SystemPermission] { get }

    /// Whether this provider is currently enabled
    var isEnabled: Bool { get }
}

extension ToolProvider {
    /// Default: no permissions required
    var requiredPermissions: [SystemPermission] { [] }

    /// Default: enabled
    var isEnabled: Bool { true }
}
```

- [ ] **Step 3: Verify build compiles**

Run: `swift build 2>&1 | tail -10`
Expected: Build succeeds (no tests needed yet — these are just protocols)

- [ ] **Step 4: Commit**

```bash
git add Shellmate/Services/Tools/Core/AgentTool.swift Shellmate/Services/Tools/Core/ToolProvider.swift
git commit -m "feat: add AgentTool and ToolProvider protocols"
```

---

## Task 3: ToolRegistry Actor

**Files:**
- Create: `Shellmate/Services/Tools/Core/ToolRegistry.swift`
- Test: `ShellmateTests/Tools/Core/ToolRegistryTests.swift`

- [ ] **Step 1: Write ToolRegistry tests**

```swift
import Testing
import Foundation
@testable import Shellmate

/// Minimal test tool for registry tests.
struct StubTool: AgentTool {
    let identifier: String
    let toolDescription = "stub"
    let category: ToolCategory
    let actionTier: ActionTier = .read
    let parameterSchema = ToolInputSchema(type: "object", properties: [:], required: [])

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        .success("stub result")
    }
}

struct StubProvider: ToolProvider {
    let category: ToolCategory
    let displayName: String
    let tools: [AgentTool]
}

@Suite("ToolRegistry")
struct ToolRegistryTests {
    @Test("register and lookup tool")
    func registerAndLookup() async {
        let registry = ToolRegistry()
        let tool = StubTool(identifier: "test_tool", category: .shell)
        let provider = StubProvider(category: .shell, displayName: "Shell", tools: [tool])
        await registry.register(provider)

        let found = await registry.tool(named: "test_tool")
        #expect(found?.identifier == "test_tool")
    }

    @Test("unknown tool returns nil")
    func unknownTool() async {
        let registry = ToolRegistry()
        let found = await registry.tool(named: "nonexistent")
        #expect(found == nil)
    }

    @Test("unregister removes provider")
    func unregister() async {
        let registry = ToolRegistry()
        let tool = StubTool(identifier: "test_tool", category: .shell)
        let provider = StubProvider(category: .shell, displayName: "Shell", tools: [tool])
        await registry.register(provider)
        await registry.unregister(.shell)

        let found = await registry.tool(named: "test_tool")
        #expect(found == nil)
    }

    @Test("tools in category")
    func toolsInCategory() async {
        let registry = ToolRegistry()
        let t1 = StubTool(identifier: "a", category: .shell)
        let t2 = StubTool(identifier: "b", category: .shell)
        let provider = StubProvider(category: .shell, displayName: "Shell", tools: [t1, t2])
        await registry.register(provider)

        let tools = await registry.tools(in: .shell)
        #expect(tools.count == 2)
    }

    @Test("schema generation with category filter")
    func schemaFilter() async {
        let registry = ToolRegistry()
        let shellTool = StubTool(identifier: "shell_exec", category: .shell)
        let fileTool = StubTool(identifier: "file_read", category: .files)
        await registry.register(StubProvider(category: .shell, displayName: "Shell", tools: [shellTool]))
        await registry.register(StubProvider(category: .files, displayName: "Files", tools: [fileTool]))

        let schemas = await registry.toolSchemas(for: [.shell], denyCategories: [])
        #expect(schemas.count == 1)
        #expect(schemas[0].name == "shell_exec")
    }

    @Test("schema generation with deny filter")
    func denyFilter() async {
        let registry = ToolRegistry()
        let tool = StubTool(identifier: "shell_exec", category: .shell)
        await registry.register(StubProvider(category: .shell, displayName: "Shell", tools: [tool]))

        let schemas = await registry.toolSchemas(for: [.shell], denyCategories: [.exec])
        #expect(schemas.isEmpty)
    }

    @Test("execute routes to correct tool")
    func executeRoutes() async throws {
        let registry = ToolRegistry()
        let tool = StubTool(identifier: "test_tool", category: .shell)
        await registry.register(StubProvider(category: .shell, displayName: "Shell", tools: [tool]))

        let result = try await registry.execute(toolName: "test_tool", parameters: [:])
        #expect(result.content == "stub result")
    }

    @Test("execute unknown tool throws")
    func executeUnknown() async {
        let registry = ToolRegistry()
        do {
            _ = try await registry.execute(toolName: "nope", parameters: [:])
            #expect(Bool(false), "Should have thrown")
        } catch {
            #expect(String(describing: error).contains("Unknown tool"))
        }
    }

    @Test("enabled categories")
    func enabledCategories() async {
        let registry = ToolRegistry()
        await registry.register(StubProvider(category: .shell, displayName: "Shell", tools: []))
        await registry.register(StubProvider(category: .files, displayName: "Files", tools: []))

        let cats = await registry.enabledCategories()
        #expect(cats.contains(.shell))
        #expect(cats.contains(.files))
        #expect(!cats.contains(.calendar))
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter "ToolRegistry" 2>&1 | tail -20`
Expected: Compilation errors — `ToolRegistry` doesn't exist

- [ ] **Step 3: Implement ToolRegistry**

```swift
// Shellmate/Services/Tools/Core/ToolRegistry.swift
import Foundation
import os

/// Central registry for all tool providers. Routes tool execution and schema generation.
actor ToolRegistry {
    private static let logger = Logger(subsystem: "com.shellmate.app", category: "tool-registry")
    private var providers: [ToolCategory: ToolProvider] = [:]
    private var toolIndex: [String: AgentTool] = [:]

    func register(_ provider: ToolProvider) {
        providers[provider.category] = provider
        for tool in provider.tools {
            toolIndex[tool.identifier] = tool
        }
        Self.logger.info("Registered \(provider.tools.count) tools for \(provider.category.rawValue)")
    }

    func unregister(_ category: ToolCategory) {
        if let provider = providers.removeValue(forKey: category) {
            for tool in provider.tools {
                toolIndex.removeValue(forKey: tool.identifier)
            }
            Self.logger.info("Unregistered \(category.rawValue)")
        }
    }

    func execute(toolName: String, parameters: [String: Any]) async throws -> AgentToolResult {
        guard let tool = toolIndex[toolName] else {
            throw ToolRegistryError.unknownTool(toolName)
        }
        return try await tool.execute(parameters: parameters)
    }

    func tool(named identifier: String) -> AgentTool? {
        toolIndex[identifier]
    }

    func tools(in category: ToolCategory) -> [AgentTool] {
        providers[category]?.tools ?? []
    }

    func enabledCategories() -> [ToolCategory] {
        providers.keys.filter { providers[$0]?.isEnabled == true }.sorted { $0.rawValue < $1.rawValue }
    }

    func toolSchemas(for categories: Set<ToolCategory>, denyCategories: [ToolDenyCategory] = []) -> [ToolDefinition] {
        let blocked = Set(denyCategories.flatMap(\.blockedTools))
        return categories.flatMap { cat -> [ToolDefinition] in
            guard let provider = providers[cat], provider.isEnabled else { return [] }
            return provider.tools
                .filter { !blocked.contains($0.identifier) }
                .map { $0.toToolDefinition() }
        }
    }

    func allToolSchemas() -> [ToolDefinition] {
        toolSchemas(for: Set(providers.keys))
    }
}

enum ToolRegistryError: Error, LocalizedError {
    case unknownTool(String)

    var errorDescription: String? {
        switch self {
        case .unknownTool(let name): "Unknown tool: \(name)"
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter "ToolRegistry" 2>&1 | tail -20`
Expected: All tests PASS

- [ ] **Step 5: Commit**

```bash
git add Shellmate/Services/Tools/Core/ToolRegistry.swift ShellmateTests/Tools/Core/ToolRegistryTests.swift
git commit -m "feat: add ToolRegistry actor with provider management and schema filtering"
```

---

## Task 4: CategoryResolver

**Files:**
- Create: `Shellmate/Services/Tools/Core/CategoryResolver.swift`
- Test: `ShellmateTests/Tools/Core/CategoryResolverTests.swift`

- [ ] **Step 1: Write CategoryResolver tests**

```swift
import Testing
import Foundation
@testable import Shellmate

@Suite("CategoryResolver")
struct CategoryResolverTests {
    let resolver = CategoryResolver()
    let allEnabled = Set(ToolCategory.allCases)

    @Test("matches calendar keywords")
    func calendarKeywords() {
        let cats = resolver.resolve(message: "What's on my calendar tomorrow?", enabledCategories: allEnabled)
        #expect(cats.contains(.calendar))
    }

    @Test("matches file keywords")
    func fileKeywords() {
        let cats = resolver.resolve(message: "Show me the files in my Downloads folder", enabledCategories: allEnabled)
        #expect(cats.contains(.files))
    }

    @Test("matches shell keywords")
    func shellKeywords() {
        let cats = resolver.resolve(message: "Run the command to check disk space", enabledCategories: allEnabled)
        #expect(cats.contains(.shell))
    }

    @Test("always includes shell and files")
    func alwaysIncluded() {
        let cats = resolver.resolve(message: "What's the weather?", enabledCategories: allEnabled)
        #expect(cats.contains(.shell))
        #expect(cats.contains(.files))
    }

    @Test("falls back to all when no keywords match")
    func fallbackToAll() {
        let cats = resolver.resolve(message: "Help me with something", enabledCategories: allEnabled)
        #expect(cats == allEnabled)
    }

    @Test("respects enabled filter")
    func respectsEnabled() {
        let limited: Set<ToolCategory> = [.shell, .files]
        let cats = resolver.resolve(message: "Check my calendar", enabledCategories: limited)
        // Calendar not enabled, so falls back to all enabled
        #expect(!cats.contains(.calendar))
    }

    @Test("case insensitive")
    func caseInsensitive() {
        let cats = resolver.resolve(message: "SHOW MY CALENDAR EVENTS", enabledCategories: allEnabled)
        #expect(cats.contains(.calendar))
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter "CategoryResolver" 2>&1 | tail -20`
Expected: Compilation error

- [ ] **Step 3: Implement CategoryResolver**

```swift
// Shellmate/Services/Tools/Core/CategoryResolver.swift
import Foundation

/// Determines which tool categories to include in LLM requests based on message keywords.
/// This is a token-cost optimization, not a routing mechanism. False positives are acceptable;
/// false negatives are not. Falls back to all enabled categories when ambiguous.
struct CategoryResolver: Sendable {
    /// Categories always included regardless of keywords.
    private static let alwaysIncluded: Set<ToolCategory> = [.shell, .files]

    private static let keywordMap: [ToolCategory: [String]] = [
        .calendar: ["calendar", "event", "schedule", "meeting", "appointment", "busy", "free time"],
        .reminders: ["remind", "reminder", "todo", "to-do", "task", "due"],
        .contacts: ["contact", "phone number", "email address", "address book"],
        .notes: ["note", "notes app", "write a note", "jot down"],
        .email: ["email", "mail", "inbox", "send a message", "unread"],
        .clipboard: ["clipboard", "paste", "copy"],
        .system: ["system info", "cpu", "memory", "ram", "disk space", "storage", "battery", "uptime"],
        .display: ["brightness", "dark mode", "night shift", "resolution", "display"],
        .audio: ["volume", "mute", "audio", "sound", "music", "playing", "song", "speaker"],
        .screenshot: ["screenshot", "screen capture", "screen shot"],
        .apps: ["install", "uninstall", "update app", "homebrew", "brew", "app store"],
        .web: ["search the web", "look up", "fetch page", "download"],
        .developer: ["git", "docker", "ssh", "port", "commit", "branch", "pull", "push"],
        .network: ["wifi", "network", "bluetooth", "ping", "dns", "vpn", "internet"],
        .automation: ["shortcut", "cron", "schedule", "automate", "launch agent"],
        .media: ["image", "photo", "pdf", "resize", "convert image", "ocr"],
        .tts: ["speak", "read aloud", "text to speech", "voice"],
    ]

    func resolve(message: String, enabledCategories: Set<ToolCategory>) -> Set<ToolCategory> {
        let lower = message.lowercased()

        var matched: Set<ToolCategory> = Self.alwaysIncluded.intersection(enabledCategories)

        for (category, keywords) in Self.keywordMap {
            guard enabledCategories.contains(category) else { continue }
            if keywords.contains(where: { lower.contains($0) }) {
                matched.insert(category)
            }
        }

        // If only the always-included categories matched, fall back to all enabled
        if matched.subtracting(Self.alwaysIncluded).isEmpty {
            return enabledCategories
        }

        return matched
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter "CategoryResolver" 2>&1 | tail -20`
Expected: All tests PASS

- [ ] **Step 5: Commit**

```bash
git add Shellmate/Services/Tools/Core/CategoryResolver.swift ShellmateTests/Tools/Core/CategoryResolverTests.swift
git commit -m "feat: add CategoryResolver for keyword-based tool schema filtering"
```

---

## Task 5: Migrate Existing Tools to AgentTool Protocol

**Files:**
- Modify: `Shellmate/Services/Tools/FileReadTool.swift`
- Modify: `Shellmate/Services/Tools/FileWriteTool.swift`
- Modify: `Shellmate/Services/Tools/FileListTool.swift`
- Modify: `Shellmate/Services/Tools/WebFetchTool.swift`
- Modify: `Shellmate/Services/Tools/WebSearchTool.swift`
- Create: `Shellmate/Services/Tools/Files/FilesProvider.swift`
- Create: `Shellmate/Services/Tools/Web/WebProvider.swift`

- [ ] **Step 1: Migrate FileReadTool**

Change `enum FileReadTool` to `struct FileReadTool: AgentTool`. Add protocol properties. Change `static func execute(input:) -> ToolExecutionResult` to `func execute(parameters:) async throws -> AgentToolResult`. Keep all existing logic identical.

```swift
// Shellmate/Services/Tools/FileReadTool.swift
import Foundation

struct FileReadTool: AgentTool {
    let identifier = "file_read"
    let toolDescription = "Read the contents of a file on the user's Mac."
    let category = ToolCategory.files
    let actionTier = ActionTier.read
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "path": ToolProperty(type: "string", description: "Absolute path to the file to read"),
        ],
        required: ["path"]
    )

    private let maxSize = 2 * 1024 * 1024 // 2MB

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        guard let path = parameters["path"] as? String else {
            return .error("Missing required 'path' parameter")
        }

        if SecurityPolicy.isPathBlocked(path) {
            return .error("Access denied: path is restricted")
        }

        let url = URL(fileURLWithPath: path).standardized

        guard FileManager.default.fileExists(atPath: url.path) else {
            return .error("File not found: \(path)")
        }

        do {
            let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
            let size = attrs[.size] as? Int ?? 0
            if size > maxSize {
                return .error("File too large (\(size) bytes, max \(maxSize))")
            }

            let content = try String(contentsOf: url, encoding: .utf8)
            return .success(content)
        } catch {
            return .error("Failed to read file: \(error.localizedDescription)")
        }
    }
}
```

- [ ] **Step 2: Migrate FileWriteTool**

Same pattern. Add `confirmationDescription` since it's `.write` tier.

```swift
// Shellmate/Services/Tools/FileWriteTool.swift
import Foundation

struct FileWriteTool: AgentTool {
    let identifier = "file_write"
    let toolDescription = "Write content to a file on the user's Mac. Creates the file and parent directories if they don't exist."
    let category = ToolCategory.files
    let actionTier = ActionTier.write
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "path": ToolProperty(type: "string", description: "Absolute path to the file to write"),
            "content": ToolProperty(type: "string", description: "Content to write to the file"),
        ],
        required: ["path", "content"]
    )

    func confirmationDescription(parameters: [String: Any]) -> String {
        let path = parameters["path"] as? String ?? "unknown path"
        return "I'd like to write to the file at \(path)."
    }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        guard let path = parameters["path"] as? String else {
            return .error("Missing required 'path' parameter")
        }
        guard let content = parameters["content"] as? String else {
            return .error("Missing required 'content' parameter")
        }

        if SecurityPolicy.isPathBlocked(path) {
            return .error("Access denied: path is restricted")
        }

        let url = URL(fileURLWithPath: path).standardized

        do {
            let parentDir = url.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
            try content.write(to: url, atomically: true, encoding: .utf8)
            return .success("File written: \(path)")
        } catch {
            return .error("Failed to write file: \(error.localizedDescription)")
        }
    }
}
```

- [ ] **Step 3: Migrate FileListTool**

```swift
// Shellmate/Services/Tools/FileListTool.swift
import Foundation

struct FileListTool: AgentTool {
    let identifier = "file_list"
    let toolDescription = "List files and directories at a given path on the user's Mac."
    let category = ToolCategory.files
    let actionTier = ActionTier.read
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "path": ToolProperty(type: "string", description: "Absolute path to the directory to list"),
            "depth": ToolProperty(type: "integer", description: "Maximum depth to recurse (default 2)"),
        ],
        required: ["path"]
    )

    private let defaultDepth = 2
    private let maxEntries = 500

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        guard let path = parameters["path"] as? String else {
            return .error("Missing required 'path' parameter")
        }

        if SecurityPolicy.isPathBlocked(path) {
            return .error("Access denied: path is restricted")
        }

        let maxDepth = (parameters["depth"] as? Int) ?? defaultDepth
        let url = URL(fileURLWithPath: path).standardized

        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else {
            return .error("Not a directory: \(path)")
        }

        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return .error("Failed to list directory")
        }

        var entries: [String] = []
        let basePath = url.path

        while let itemURL = enumerator.nextObject() as? URL {
            let relativePath = itemURL.path.replacingOccurrences(of: basePath + "/", with: "")
            let depth = relativePath.components(separatedBy: "/").count
            if depth > maxDepth {
                enumerator.skipDescendants()
                continue
            }

            let isDirectory = (try? itemURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            entries.append(relativePath + (isDirectory ? "/" : ""))

            if entries.count >= maxEntries {
                entries.append("... (truncated at \(maxEntries) entries)")
                break
            }
        }

        return .success(entries.isEmpty ? "(empty directory)" : entries.joined(separator: "\n"))
    }
}
```

- [ ] **Step 4: Migrate WebSearchTool**

```swift
// Shellmate/Services/Tools/WebSearchTool.swift
import Foundation
import os

struct WebSearchTool: AgentTool {
    let identifier = "web_search"
    let toolDescription = "Search the web using Brave Search. Returns titles, URLs, and descriptions of results."
    let category = ToolCategory.web
    let actionTier = ActionTier.read
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "query": ToolProperty(type: "string", description: "The search query"),
            "count": ToolProperty(type: "integer", description: "Number of results (default 5, max 20)"),
        ],
        required: ["query"]
    )

    private static let logger = Logger(subsystem: "com.shellmate.app", category: "web-search")
    private static let baseURL = "https://api.search.brave.com/res/v1/web/search"

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        guard let query = parameters["query"] as? String else {
            return .error("Missing required 'query' parameter")
        }

        guard let apiKey = ProcessInfo.processInfo.environment["BRAVE_API_KEY"], !apiKey.isEmpty else {
            return .error("Web search unavailable: BRAVE_API_KEY not set")
        }

        let count = min((parameters["count"] as? Int) ?? 5, 20)

        guard var components = URLComponents(string: Self.baseURL) else {
            return .error("Invalid search base URL")
        }
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "count", value: "\(count)"),
        ]

        guard let url = components.url else {
            return .error("Failed to build search URL")
        }

        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "X-Subscription-Token")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return .error("Search API error")
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let web = json["web"] as? [String: Any],
                  let results = web["results"] as? [[String: Any]] else {
                return .success("No results found")
            }

            let formatted = results.prefix(count).map { result in
                let title = result["title"] as? String ?? "Untitled"
                let url = result["url"] as? String ?? ""
                let desc = result["description"] as? String ?? ""
                return "**\(title)**\n\(url)\n\(desc)"
            }.joined(separator: "\n\n")

            return .success(formatted)
        } catch {
            return .error("Search failed: \(error.localizedDescription)")
        }
    }
}
```

- [ ] **Step 5: Migrate WebFetchTool**

Same pattern — change `enum` to `struct: AgentTool`, replace `ToolExecutionResult` with `AgentToolResult`. Keep `SSRFProtectedSession` and `SSRFRedirectDelegate` unchanged in the same file.

```swift
// Shellmate/Services/Tools/WebFetchTool.swift — change the first line and struct definition:
struct WebFetchTool: AgentTool {
    let identifier = "web_fetch"
    let toolDescription = "Fetch the contents of a web page and extract the text."
    let category = ToolCategory.web
    let actionTier = ActionTier.read
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "url": ToolProperty(type: "string", description: "The URL to fetch"),
        ],
        required: ["url"]
    )

    // ... rest of execute() logic unchanged, just:
    // - Change `static func execute(input:)` to `func execute(parameters:)`
    // - Change all `ToolExecutionResult(content:isError:)` to `AgentToolResult.success()` / `.error()`
    // - Change `input["url"]` to `parameters["url"]`
    // - Keep extractText as a private method (no longer static)
    // - Keep SSRFProtectedSession and SSRFRedirectDelegate unchanged
}
```

- [ ] **Step 6: Create FilesProvider**

```swift
// Shellmate/Services/Tools/Files/FilesProvider.swift
import Foundation

struct FilesProvider: ToolProvider {
    let category = ToolCategory.files
    let displayName = "Files & Storage"

    var tools: [AgentTool] {
        [FileReadTool(), FileWriteTool(), FileListTool()]
    }
}
```

- [ ] **Step 7: Create WebProvider**

```swift
// Shellmate/Services/Tools/Web/WebProvider.swift
import Foundation

struct WebProvider: ToolProvider {
    let category = ToolCategory.web
    let displayName = "Web & Search"

    var tools: [AgentTool] {
        [WebSearchTool(), WebFetchTool()]
    }
}
```

- [ ] **Step 8: Add backward-compatible static shims to keep build green**

Each migrated tool keeps a temporary static `execute(input:)` method that delegates to the instance method. This prevents build breaks in `ToolExecutor.swift` and existing tests until Task 8 removes the switch statement. Add this extension to each tool file:

```swift
// Temporary compat shim — removed in Task 8
extension FileReadTool {
    static func execute(input: [String: Any]) -> ToolExecutionResult {
        // Bridge: run the async instance method synchronously for legacy callers
        // This is safe because the old static method was also sync
        let tool = FileReadTool()
        let result = try? _syncExecute(tool: tool, parameters: input)
        return ToolExecutionResult(content: result?.content ?? "Error", isError: result?.isError ?? true)
    }
}

// For async tools (WebSearchTool, WebFetchTool), keep the old static signature:
extension WebSearchTool {
    static func execute(input: [String: Any]) async -> ToolExecutionResult {
        let tool = WebSearchTool()
        do {
            let result = try await tool.execute(parameters: input)
            return ToolExecutionResult(content: result.content, isError: result.isError)
        } catch {
            return ToolExecutionResult(content: error.localizedDescription, isError: true)
        }
    }
}
```

Apply the same pattern to FileWriteTool, FileListTool, and WebFetchTool.

- [ ] **Step 9: Update FileToolTests and WebToolTests for new instance API**

For `ShellmateTests/FileToolTests.swift`, change all `FileReadTool.execute(input:)` to `FileReadTool().execute(parameters:)` etc. Change `ToolExecutionResult` assertions to work with `AgentToolResult` (same fields: `.content`, `.isError`). Add `async throws` to non-async test functions since `execute(parameters:)` is now `async throws`.

For `ShellmateTests/WebToolTests.swift`, apply the same pattern.

- [ ] **Step 10: Run existing tests to verify nothing broke**

Run: `swift test 2>&1 | tail -30`
Expected: All tests PASS (compat shims keep old callers working)

- [ ] **Step 11: Commit**

```bash
git add Shellmate/Services/Tools/FileReadTool.swift Shellmate/Services/Tools/FileWriteTool.swift Shellmate/Services/Tools/FileListTool.swift Shellmate/Services/Tools/WebSearchTool.swift Shellmate/Services/Tools/WebFetchTool.swift Shellmate/Services/Tools/Files/FilesProvider.swift Shellmate/Services/Tools/Web/WebProvider.swift ShellmateTests/FileToolTests.swift ShellmateTests/WebToolTests.swift
git commit -m "refactor: migrate 5 tools from static enums to AgentTool protocol conformance"
```

---

## Task 6: ShellService Actor + ShellExecuteTool

**Files:**
- Create: `Shellmate/Services/Tools/Shell/ShellService.swift`
- Create: `Shellmate/Services/Tools/Shell/ShellExecuteTool.swift`
- Create: `Shellmate/Services/Tools/Shell/ShellProvider.swift`
- Delete: `Shellmate/Services/Tools/ShellTool.swift`
- Test: `ShellmateTests/Tools/Shell/ShellServiceTests.swift`

- [ ] **Step 1: Write ShellService tests**

```swift
import Testing
import Foundation
@testable import Shellmate

@Suite("ShellService")
struct ShellServiceTests {
    @Test("runCommand succeeds with simple echo")
    func echoCommand() async throws {
        let service = ShellService()
        let result = try await service.runCommand("echo hello")
        #expect(result.succeeded)
        #expect(result.stdout.contains("hello"))
        #expect(result.exitCode == 0)
    }

    @Test("runCommand reports exit code on failure")
    func failingCommand() async throws {
        let service = ShellService()
        let result = try await service.runCommand("false")
        #expect(!result.succeeded)
        #expect(result.exitCode != 0)
    }

    @Test("runCommand blocks dangerous commands")
    func blockedCommand() async {
        let service = ShellService()
        do {
            _ = try await service.runCommand("sudo rm -rf /")
            #expect(Bool(false), "Should have thrown")
        } catch {
            #expect(String(describing: error).contains("blocked") || String(describing: error).contains("denied"))
        }
    }

    @Test("runCommand respects timeout")
    func timeout() async throws {
        let service = ShellService()
        let result = try await service.runCommand("sleep 10", timeout: 1)
        #expect(!result.succeeded)
    }

    @Test("run with structured arguments")
    func structuredRun() async throws {
        let service = ShellService()
        let result = try await service.run(executable: "/bin/echo", arguments: ["hello", "world"])
        #expect(result.succeeded)
        #expect(result.stdout.contains("hello world"))
    }

    @Test("which finds echo")
    func whichEcho() async {
        let service = ShellService()
        let path = await service.which("echo")
        #expect(path != nil)
    }

    @Test("which returns nil for nonexistent")
    func whichMissing() async {
        let service = ShellService()
        let path = await service.which("nonexistent_command_xyz")
        #expect(path == nil)
    }

    @Test("history tracks commands")
    func historyTracking() async throws {
        let service = ShellService()
        _ = try await service.runCommand("echo test1")
        _ = try await service.runCommand("echo test2")
        let history = await service.recentHistory(limit: 10)
        #expect(history.count == 2)
    }

    @Test("output is capped at 1MB")
    func outputCapping() async throws {
        let service = ShellService()
        // Generate > 1MB of output
        let result = try await service.runCommand("python3 -c \"print('x' * 2_000_000)\"")
        #expect(result.stdout.count <= 1_048_576 + 100) // 1MB + small buffer for truncation message
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter "ShellService" 2>&1 | tail -20`
Expected: Compilation error

- [ ] **Step 3: Implement ShellService**

```swift
// Shellmate/Services/Tools/Shell/ShellService.swift
import Foundation
import os

actor ShellService {
    private static let logger = Logger(subsystem: "com.shellmate.app", category: "shell-service")
    private static let maxOutputBytes = 1_048_576 // 1MB per stream
    private static let maxHistorySize = 100

    private var history: [ShellHistoryEntry] = []
    private var environmentCache: [String: String]?

    // MARK: - Structured Execution

    func run(
        executable: String,
        arguments: [String] = [],
        environment: [String: String]? = nil,
        workingDirectory: URL? = nil,
        timeout: TimeInterval = 300
    ) async throws -> ShellResult {
        // Resolve to absolute path
        guard let execURL = await which(executable) ?? URL(fileURLWithPath: executable) as URL?,
              FileManager.default.fileExists(atPath: execURL.path) else {
            throw ShellServiceError.commandNotFound(executable)
        }

        return try await executeProcess(
            executableURL: execURL,
            arguments: arguments,
            environment: environment,
            workingDirectory: workingDirectory,
            timeout: timeout,
            logCommand: "\(executable) \(arguments.joined(separator: " "))"
        )
    }

    // MARK: - String Command Execution

    func runCommand(
        _ command: String,
        workingDirectory: URL? = nil,
        timeout: TimeInterval = 60
    ) async throws -> ShellResult {
        if let blocked = SecurityPolicy.checkShellCommand(command) {
            throw ShellServiceError.commandBlocked(blocked)
        }

        Self.logger.info("Executing shell command (\(command.count) chars, timeout: \(Int(timeout))s)")

        return try await executeProcess(
            executableURL: URL(fileURLWithPath: "/bin/zsh"),
            arguments: ["-c", command],
            environment: nil,
            workingDirectory: workingDirectory,
            timeout: timeout,
            logCommand: command
        )
    }

    // MARK: - Utilities

    func which(_ command: String) async -> URL? {
        // Check if already absolute
        if command.hasPrefix("/") {
            return FileManager.default.fileExists(atPath: command) ? URL(fileURLWithPath: command) : nil
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = [command]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return path.isEmpty ? nil : URL(fileURLWithPath: path)
        } catch {
            return nil
        }
    }

    func environment() async -> [String: String] {
        if let cached = environmentCache { return cached }
        let env = ProcessInfo.processInfo.environment
        environmentCache = env
        return env
    }

    func recentHistory(limit: Int = 20) -> [ShellHistoryEntry] {
        Array(history.suffix(limit))
    }

    // MARK: - Private

    private func executeProcess(
        executableURL: URL,
        arguments: [String],
        environment: [String: String]?,
        workingDirectory: URL?,
        timeout: TimeInterval,
        logCommand: String
    ) async throws -> ShellResult {
        let start = Date()
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments
        process.currentDirectoryURL = workingDirectory ?? FileManager.default.homeDirectoryForCurrentUser
        if let env = environment {
            process.environment = env
        }

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
        } catch {
            throw ShellServiceError.processStartFailed(error.localizedDescription)
        }

        let result: ShellResult = await withTaskGroup(of: ShellResult?.self) { group in
            group.addTask {
                process.waitUntilExit()

                let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

                let stdout = String(
                    data: stdoutData.prefix(ShellService.maxOutputBytes),
                    encoding: .utf8
                ) ?? ""
                let stderr = String(
                    data: stderrData.prefix(ShellService.maxOutputBytes),
                    encoding: .utf8
                ) ?? ""

                return ShellResult(
                    exitCode: process.terminationStatus,
                    stdout: stdout,
                    stderr: stderr,
                    duration: Date().timeIntervalSince(start)
                )
            }

            group.addTask {
                try? await Task.sleep(for: .seconds(timeout))
                if process.isRunning {
                    process.terminate()
                    // Give it 5 seconds, then SIGKILL
                    try? await Task.sleep(for: .seconds(5))
                    if process.isRunning {
                        kill(process.processIdentifier, SIGKILL)
                    }
                    return ShellResult(
                        exitCode: -1,
                        stdout: "",
                        stderr: "Command timed out after \(Int(timeout))s",
                        duration: timeout
                    )
                }
                return nil
            }

            for await r in group {
                if let r { return r }
            }
            return ShellResult(exitCode: -1, stdout: "", stderr: "Unknown error", duration: 0)
        }

        // Record in history
        let entry = ShellHistoryEntry(
            id: UUID(),
            command: logCommand,
            exitCode: result.exitCode,
            timestamp: start,
            duration: result.duration
        )
        history.append(entry)
        if history.count > Self.maxHistorySize {
            history.removeFirst(history.count - Self.maxHistorySize)
        }

        return result
    }
}

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

enum ShellServiceError: Error, LocalizedError {
    case commandNotFound(String)
    case commandBlocked(String)
    case processStartFailed(String)

    var errorDescription: String? {
        switch self {
        case .commandNotFound(let cmd): "Command not found: \(cmd)"
        case .commandBlocked(let reason): "Access denied: \(reason)"
        case .processStartFailed(let reason): "Failed to start process: \(reason)"
        }
    }
}
```

- [ ] **Step 4: Implement ShellExecuteTool**

```swift
// Shellmate/Services/Tools/Shell/ShellExecuteTool.swift
import Foundation

struct ShellExecuteTool: AgentTool {
    let identifier = "shell_exec"
    let toolDescription = "Execute a shell command on the user's Mac. Use for running terminal commands, installing software, checking system info, etc."
    let category = ToolCategory.shell
    let actionTier = ActionTier.write
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "command": ToolProperty(type: "string", description: "The shell command to execute"),
            "timeout": ToolProperty(type: "integer", description: "Timeout in seconds (default 60)"),
        ],
        required: ["command"]
    )

    private let shellService: ShellService

    init(service: ShellService) {
        self.shellService = service
    }

    func confirmationDescription(parameters: [String: Any]) -> String {
        let command = parameters["command"] as? String ?? "unknown command"
        let display = command.count > 80 ? String(command.prefix(80)) + "..." : command
        return "I'd like to run this command: \(display)"
    }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        guard let command = parameters["command"] as? String else {
            return .error("Missing required 'command' parameter")
        }

        let timeout = (parameters["timeout"] as? Double) ?? 60

        do {
            let result = try await shellService.runCommand(command, timeout: timeout)

            var output = result.stdout
            if !result.stderr.isEmpty {
                output += (output.isEmpty ? "" : "\n") + "STDERR: \(result.stderr)"
            }
            if result.exitCode != 0 {
                output += "\nExit code: \(result.exitCode)"
            }

            return AgentToolResult(
                content: output.isEmpty ? "(no output)" : output,
                isError: !result.succeeded,
                metadata: ["exit_code": "\(result.exitCode)"]
            )
        } catch {
            return .error(error.localizedDescription)
        }
    }
}
```

- [ ] **Step 5: Implement ShellProvider**

```swift
// Shellmate/Services/Tools/Shell/ShellProvider.swift
import Foundation

struct ShellProvider: ToolProvider {
    let category = ToolCategory.shell
    let displayName = "Shell & Terminal"
    private let shellService: ShellService

    init(shellService: ShellService) {
        self.shellService = shellService
    }

    var tools: [AgentTool] {
        [ShellExecuteTool(service: shellService)]
    }
}
```

- [ ] **Step 6: Delete old ShellTool.swift**

```bash
git rm Shellmate/Services/Tools/ShellTool.swift
```

- [ ] **Step 7: Run ShellService tests**

Run: `swift test --filter "ShellService" 2>&1 | tail -20`
Expected: All tests PASS

- [ ] **Step 8: Commit**

```bash
git add Shellmate/Services/Tools/Shell/ ShellmateTests/Tools/Shell/
git add -u Shellmate/Services/Tools/ShellTool.swift
git commit -m "feat: add ShellService actor and ShellExecuteTool, remove old ShellTool"
```

---

## Task 7: ConfirmationService + PermissionManager

**Files:**
- Create: `Shellmate/Services/Shared/ConfirmationService.swift`
- Create: `Shellmate/Services/Shared/PermissionManager.swift`
- Modify: `Shellmate/State/ChatState.swift`
- Test: `ShellmateTests/Tools/Shared/ConfirmationServiceTests.swift`
- Test: `ShellmateTests/Tools/Shared/PermissionManagerTests.swift`

- [ ] **Step 1: Write ConfirmationService tests**

```swift
import Testing
import Foundation
@testable import Shellmate

@Suite("ConfirmationService")
struct ConfirmationServiceTests {
    @Test("read tier auto-approves")
    func readTierAutoApproves() async {
        let service = ConfirmationService(uiHandler: MockConfirmationUIHandler(alwaysApprove: false))
        let tool = StubTool(identifier: "test", category: .files)
        // Read tier should not call the UI handler at all
        let approved = await service.confirm(tool: tool, parameters: [:])
        #expect(approved)
    }

    @Test("write tier calls UI handler")
    func writeTierCallsUI() async {
        let handler = MockConfirmationUIHandler(alwaysApprove: true)
        let service = ConfirmationService(uiHandler: handler)
        let tool = WriteTierStubTool()
        let approved = await service.confirm(tool: tool, parameters: [:])
        #expect(approved)
    }

    @Test("write tier denied returns false")
    func writeTierDenied() async {
        let handler = MockConfirmationUIHandler(alwaysApprove: false)
        let service = ConfirmationService(uiHandler: handler)
        let tool = WriteTierStubTool()
        let approved = await service.confirm(tool: tool, parameters: [:])
        #expect(!approved)
    }

    @Test("auto-approve skips UI for write tier")
    func autoApprove() async {
        let handler = MockConfirmationUIHandler(alwaysApprove: false)
        let service = ConfirmationService(uiHandler: handler)
        await service.setAutoApprove(for: .files, enabled: true)
        let tool = WriteTierStubTool()
        let approved = await service.confirm(tool: tool, parameters: [:])
        #expect(approved) // Should bypass UI handler
    }

    @Test("destructive tier never auto-approves")
    func destructiveNeverAutoApproves() async {
        let handler = MockConfirmationUIHandler(alwaysApprove: false)
        let service = ConfirmationService(uiHandler: handler)
        await service.setAutoApprove(for: .files, enabled: true)
        let tool = DestructiveTierStubTool()
        let approved = await service.confirm(tool: tool, parameters: [:])
        #expect(!approved) // Must go through UI, which denies
    }
}

// Test helpers
struct WriteTierStubTool: AgentTool {
    let identifier = "write_test"
    let toolDescription = "test"
    let category = ToolCategory.files
    let actionTier = ActionTier.write
    let parameterSchema = ToolInputSchema(type: "object", properties: [:], required: [])
    func execute(parameters: [String: Any]) async throws -> AgentToolResult { .success("ok") }
    func confirmationDescription(parameters: [String: Any]) -> String { "test write" }
}

struct DestructiveTierStubTool: AgentTool {
    let identifier = "destroy_test"
    let toolDescription = "test"
    let category = ToolCategory.files
    let actionTier = ActionTier.destructive
    let parameterSchema = ToolInputSchema(type: "object", properties: [:], required: [])
    func execute(parameters: [String: Any]) async throws -> AgentToolResult { .success("ok") }
    func confirmationDescription(parameters: [String: Any]) -> String { "test destroy" }
}

final class MockConfirmationUIHandler: ConfirmationUIHandling, @unchecked Sendable {
    let alwaysApprove: Bool
    init(alwaysApprove: Bool) { self.alwaysApprove = alwaysApprove }
    func requestConfirmation(toolIdentifier: String, description: String, tier: ActionTier) async -> Bool {
        alwaysApprove
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter "ConfirmationService" 2>&1 | tail -20`
Expected: Compilation error

- [ ] **Step 3: Implement ConfirmationService**

```swift
// Shellmate/Services/Shared/ConfirmationService.swift
import Foundation

/// Protocol for UI confirmation handling (allows mocking in tests).
protocol ConfirmationUIHandling: Sendable {
    func requestConfirmation(toolIdentifier: String, description: String, tier: ActionTier) async -> Bool
}

/// Gates tool execution based on ActionTier.
actor ConfirmationService {
    private var autoApproveCategories: Set<ToolCategory> = []
    private let uiHandler: ConfirmationUIHandling

    init(uiHandler: ConfirmationUIHandling) {
        self.uiHandler = uiHandler
    }

    func confirm(tool: AgentTool, parameters: [String: Any]) async -> Bool {
        // Read tier always proceeds
        if tool.actionTier == .read { return true }

        // Auto-approve .write tier if user opted in (never for destructive)
        if tool.actionTier == .write && autoApproveCategories.contains(tool.category) {
            return true
        }

        let description = tool.confirmationDescription(parameters: parameters)
        return await uiHandler.requestConfirmation(
            toolIdentifier: tool.identifier,
            description: description,
            tier: tool.actionTier
        )
    }

    func setAutoApprove(for category: ToolCategory, enabled: Bool) {
        if enabled {
            autoApproveCategories.insert(category)
        } else {
            autoApproveCategories.remove(category)
        }
    }

    func isAutoApproved(_ category: ToolCategory) -> Bool {
        autoApproveCategories.contains(category)
    }
}

/// MainActor UI handler that bridges to ChatState for real confirmation cards.
@MainActor
final class ConfirmationUIHandler: ConfirmationUIHandling {
    nonisolated func requestConfirmation(toolIdentifier: String, description: String, tier: ActionTier) async -> Bool {
        await MainActor.run {
            // This will be wired to ChatState.pendingConfirmation in the UI integration task
            // For now, auto-approve (will be replaced)
            true
        }
    }
}
```

- [ ] **Step 4: Add pendingConfirmation to ChatState**

Add to `Shellmate/State/ChatState.swift` after the `error` property (line 15):

```swift
var pendingConfirmation: ConfirmationRequest?
```

And add the `ConfirmationRequest` model at the end of the file:

```swift
/// One-shot continuation wrapper — ensures the continuation is only resumed once,
/// even if the user somehow triggers both buttons (double-tap, accessibility, etc.)
final class OneShotContinuation: @unchecked Sendable {
    private var continuation: CheckedContinuation<Bool, Never>?
    private let lock = NSLock()

    init(_ continuation: CheckedContinuation<Bool, Never>) {
        self.continuation = continuation
    }

    func resume(returning value: Bool) {
        lock.lock()
        let cont = continuation
        continuation = nil
        lock.unlock()
        cont?.resume(returning: value)
    }
}

struct ConfirmationRequest: Identifiable, Sendable {
    let id: UUID
    let toolIdentifier: String
    let description: String
    let tier: ActionTier
    let continuation: OneShotContinuation
}
```

- [ ] **Step 5: Implement PermissionManager**

```swift
// Shellmate/Services/Shared/PermissionManager.swift
import Foundation
import os
import AppKit

actor PermissionManager {
    private static let logger = Logger(subsystem: "com.shellmate.app", category: "permissions")
    private var cache: [SystemPermission: PermissionStatus] = [:]

    enum PermissionStatus: Sendable {
        case notRequested, granted, denied, restricted
    }

    func status(for permission: SystemPermission) -> PermissionStatus {
        cache[permission] ?? .notRequested
    }

    func updateStatus(_ permission: SystemPermission, to status: PermissionStatus) {
        cache[permission] = status
        Self.logger.info("Permission \(permission.rawValue) → \(String(describing: status))")
    }

    func allStatuses() -> [SystemPermission: PermissionStatus] {
        var result: [SystemPermission: PermissionStatus] = [:]
        for perm in SystemPermission.allCases {
            result[perm] = cache[perm] ?? .notRequested
        }
        return result
    }

    /// Check permissions for a tool. Returns an error message if denied, nil if OK.
    func checkPermissions(for tool: AgentTool) -> String? {
        // Tools don't directly declare permissions — their provider does.
        // This is a convenience that will be wired through the provider's requiredPermissions.
        nil
    }

    @MainActor
    func openSettings(for permission: SystemPermission) {
        NSWorkspace.shared.open(permission.settingsPaneURL)
    }
}
```

- [ ] **Step 6: Write PermissionManager tests**

```swift
import Testing
import Foundation
@testable import Shellmate

@Suite("PermissionManager")
struct PermissionManagerTests {
    @Test("initial status is notRequested")
    func initialStatus() async {
        let manager = PermissionManager()
        let status = await manager.status(for: .calendars)
        #expect(status == .notRequested)
    }

    @Test("update status is reflected")
    func updateStatus() async {
        let manager = PermissionManager()
        await manager.updateStatus(.calendars, to: .granted)
        let status = await manager.status(for: .calendars)
        #expect(status == .granted)
    }

    @Test("allStatuses covers all permissions")
    func allStatuses() async {
        let manager = PermissionManager()
        let statuses = await manager.allStatuses()
        #expect(statuses.count == SystemPermission.allCases.count)
    }
}
```

- [ ] **Step 7: Run tests**

Run: `swift test --filter "ConfirmationService|PermissionManager" 2>&1 | tail -20`
Expected: All PASS

- [ ] **Step 8: Commit**

```bash
git add Shellmate/Services/Shared/ Shellmate/State/ChatState.swift ShellmateTests/Tools/Shared/
git commit -m "feat: add ConfirmationService actor, PermissionManager, and ChatState confirmation support"
```

---

## Task 8: Refactor ToolExecutor + ToolUseLoop + Update Tests

**Files:**
- Modify: `Shellmate/Services/Tools/ToolExecutor.swift`
- Modify: `Shellmate/Services/AI/ToolUseLoop.swift`
- Modify: `Shellmate/Models/ToolDefinition.swift`
- Modify: `Shellmate/Models/ShellmateConfig.swift`
- Modify: `ShellmateTests/ToolExecutorTests.swift`
- Modify: `ShellmateTests/ToolDefinitionTests.swift`

- [ ] **Step 1: Refactor ToolExecutor to use ToolRegistry**

Replace the entire file:

```swift
// Shellmate/Services/Tools/ToolExecutor.swift
import Foundation
import os

/// Result of a tool execution (bridge type for ToolUseLoop compatibility).
struct ToolExecutionResult: Sendable {
    let content: String
    let isError: Bool
}

/// Routes tool calls through the registry with permission and confirmation checks.
actor ToolExecutor {
    private static let logger = Logger(subsystem: "com.shellmate.app", category: "tools")
    let registry: ToolRegistry
    private let confirmationService: ConfirmationService
    private let permissionManager: PermissionManager

    init(registry: ToolRegistry, confirmationService: ConfirmationService, permissionManager: PermissionManager) {
        self.registry = registry
        self.confirmationService = confirmationService
        self.permissionManager = permissionManager
    }

    func execute(tool name: String, input: [String: JSONValue]) async -> ToolExecutionResult {
        Self.logger.info("Executing tool: \(name)")
        let anyInput = input.mapValues(\.anyValue)

        guard let tool = await registry.tool(named: name) else {
            return ToolExecutionResult(content: "Unknown tool: \(name)", isError: true)
        }

        // Permission check (no-op in Phase 1, wired in Phase 4)
        if let denied = await permissionManager.checkPermissions(for: tool) {
            return ToolExecutionResult(content: denied, isError: true)
        }

        // Confirmation check
        if tool.actionTier != .read {
            let approved = await confirmationService.confirm(tool: tool, parameters: anyInput)
            if !approved {
                return ToolExecutionResult(content: "Action cancelled by user.", isError: true)
            }
        }

        do {
            let result = try await tool.execute(parameters: anyInput)
            return ToolExecutionResult(content: result.content, isError: result.isError)
        } catch {
            return ToolExecutionResult(content: error.localizedDescription, isError: true)
        }
    }
}
```

- [ ] **Step 2: Refactor ToolUseLoop to accept injected executor**

In `Shellmate/Services/AI/ToolUseLoop.swift`, change the executor from `private let executor = ToolExecutor()` to an injected dependency. Also change schema resolution to use the registry:

Key changes to `ToolUseLoop.swift`:

1. Replace `private let executor = ToolExecutor()` with injected dependency:
```swift
private let executor: ToolExecutor
private let categoryResolver = CategoryResolver()

init(executor: ToolExecutor) {
    self.executor = executor
}
```

2. Remove the `tools: [ToolDefinition]` parameter from `run()` signature. Schemas now come from the registry.

3. Replace `let availableTools = ToolDefinitions.available(denyCategories: denyCategories)` with:
```swift
let resolvedCategories = categoryResolver.resolve(
    message: messages.last?.dict["content"] as? String ?? "",
    enabledCategories: Set(await executor.registry.enabledCategories())
)
let availableTools = await executor.registry.toolSchemas(for: resolvedCategories, denyCategories: denyCategories)
```

- [ ] **Step 3: Clean up ToolDefinition.swift — delete ToolDefinitions enum**

Keep: `ToolDenyCategory`, `ToolDefinition`, `ToolInputSchema`, `ToolProperty`, and the format conversion methods.

Delete: The `ToolDefinitions` enum (lines 54-181) — schemas now live on each tool.

Move `toAnthropicFormat` and `toOpenAIFormat` to be static methods on `ToolDefinition` (array extension):

```swift
extension Array where Element == ToolDefinition {
    func toAnthropicFormat() -> [[String: Any]] {
        map { tool in
            [
                "name": tool.name,
                "description": tool.description,
                "input_schema": [
                    "type": tool.inputSchema.type,
                    "properties": tool.inputSchema.properties.mapValues { prop in
                        var dict: [String: Any] = ["type": prop.type, "description": prop.description]
                        if let enums = prop.enumValues { dict["enum"] = enums }
                        return dict
                    },
                    "required": tool.inputSchema.required,
                ] as [String: Any],
            ] as [String: Any]
        }
    }

    func toOpenAIFormat() -> [[String: Any]] {
        map { tool in
            [
                "type": "function",
                "function": [
                    "name": tool.name,
                    "description": tool.description,
                    "parameters": [
                        "type": tool.inputSchema.type,
                        "properties": tool.inputSchema.properties.mapValues { prop in
                            var dict: [String: Any] = ["type": prop.type, "description": prop.description]
                            if let enums = prop.enumValues { dict["enum"] = enums }
                            return dict
                        },
                        "required": tool.inputSchema.required,
                    ] as [String: Any],
                ] as [String: Any],
            ] as [String: Any]
        }
    }
}
```

- [ ] **Step 4: Update AnthropicClient and OpenAIClient format calls**

In `AnthropicClient.swift` and `OpenAIClient.swift`, change `ToolDefinitions.toAnthropicFormat(tools)` → `tools.toAnthropicFormat()` and `ToolDefinitions.toOpenAIFormat(tools)` → `tools.toOpenAIFormat()`.

- [ ] **Step 5: Extend CapabilitiesConfig**

In `Shellmate/Models/ShellmateConfig.swift`, add to `CapabilitiesConfig`:

```swift
struct CapabilitiesConfig: Codable, Sendable {
    var webSearch: Bool = true
    var webFetch: Bool = true
    var memory: String = "core"
    var recommendedSkills: [String] = []
    var tools: ToolPermissions = ToolPermissions()
    var enabledCategories: [String] = ToolCategory.allCases.map(\.rawValue)
    var autoApproveCategories: [String] = []
}
```

- [ ] **Step 6: Update ToolExecutorTests**

```swift
import Testing; import Foundation; @testable import Shellmate

@Suite("ToolExecutor")
struct ToolExecutorTests {
    func makeExecutor() async -> ToolExecutor {
        let registry = ToolRegistry()
        let shellService = ShellService()
        await registry.register(ShellProvider(shellService: shellService))
        await registry.register(FilesProvider())
        await registry.register(WebProvider())
        let uiHandler = MockConfirmationUIHandler(alwaysApprove: true)
        let confirmation = ConfirmationService(uiHandler: uiHandler)
        let permissions = PermissionManager()
        return ToolExecutor(registry: registry, confirmationService: confirmation, permissionManager: permissions)
    }

    @Test("shell_exec")
    func shellExec() async {
        let executor = await makeExecutor()
        let r = await executor.execute(tool: "shell_exec", input: ["command": .string("echo hi")])
        #expect(!r.isError)
        #expect(r.content.contains("hi"))
    }

    @Test("file_read not found")
    func fileReadNotFound() async {
        let executor = await makeExecutor()
        let r = await executor.execute(tool: "file_read", input: ["path": .string("/tmp/ne_\(UUID())")])
        #expect(r.isError)
    }

    @Test("unknown tool")
    func unknownTool() async {
        let executor = await makeExecutor()
        let r = await executor.execute(tool: "nope", input: [:])
        #expect(r.isError)
        #expect(r.content.contains("Unknown"))
    }
}
```

- [ ] **Step 7: Update ChatView.swift**

In `Shellmate/Views/Chat/ChatView.swift`, replace the `sendMessage` function's tool loop creation (lines 87-90):

```swift
// Before:
let loop = ToolUseLoop()
sendTask = Task {
    await loop.run(messages: msgs, system: sp, tools: ToolDefinitions.all, provider: aiConfig.provider, model: aiConfig.model, apiKey: apiKey, denyCategories: deny, onEvent: { ... })
}

// After:
let shellService = ShellService()
let registry = ToolRegistry()
let confirmationHandler = ConfirmationUIHandler()
let confirmationService = ConfirmationService(uiHandler: confirmationHandler)
let permissionManager = PermissionManager()
let executor = ToolExecutor(registry: registry, confirmationService: confirmationService, permissionManager: permissionManager)
let loop = ToolUseLoop(executor: executor)
sendTask = Task {
    await registry.register(ShellProvider(shellService: shellService))
    await registry.register(FilesProvider())
    await registry.register(WebProvider())
    await loop.run(messages: msgs, system: sp, provider: aiConfig.provider, model: aiConfig.model, apiKey: apiKey, denyCategories: deny, onEvent: { ... })
}
```

Note: The `tools:` parameter is removed from `loop.run()`.

- [ ] **Step 8: Update ToolFormatTests, AIRouterTests, AnthropicClientTests, OpenAIClientTests**

`ToolFormatTests.swift` — change `ToolDefinitions.toAnthropicFormat([...])` to `[...].toAnthropicFormat()`, and `ToolDefinitions.all` to inline arrays of `ToolDefinition`. Remove count assertion for "6 tools" since tools are no longer centrally listed.

`AIRouterTests.swift` — replace `ToolDefinitions.all` / `ToolDefinitions.available()` with inline `ToolDefinition` arrays.

`AnthropicClientTests.swift` — replace `ToolDefinitions.shellExec` with an inline `ToolDefinition(name: "shell_exec", ...)`.

`OpenAIClientTests.swift` — replace `ToolDefinitions.webSearch` with an inline `ToolDefinition(name: "web_search", ...)`.

- [ ] **Step 9: Remove compat shims from migrated tools**

In Task 5 we added static `execute(input:)` compat shims to keep the build green during migration. Now that `ToolExecutor` uses the registry, delete these shims from `FileReadTool`, `FileWriteTool`, `FileListTool`, `WebSearchTool`, and `WebFetchTool`. Also delete `ShellmateTests/ShellToolTests.swift` (replaced by `ShellServiceTests`).

- [ ] **Step 10: Update ToolDefinitionTests**

```swift
import Testing; import Foundation; @testable import Shellmate

@Suite("ToolDefinition")
struct ToolDefinitionTests {
    @Test("deny categories block correct tools")
    func denyCategories() {
        let exec = ToolDenyCategory.exec
        #expect(exec.blockedTools.contains("shell_exec"))
    }

    @Test("Codable round-trip")
    func codable() throws {
        let def = ToolDefinition(
            name: "test",
            description: "A test tool",
            inputSchema: ToolInputSchema(type: "object", properties: [:], required: [])
        )
        let data = try JSONEncoder().encode(def)
        let decoded = try JSONDecoder().decode(ToolDefinition.self, from: data)
        #expect(decoded.name == "test")
    }

    @Test("Anthropic format")
    func anthropicFormat() {
        let def = ToolDefinition(
            name: "test",
            description: "desc",
            inputSchema: ToolInputSchema(
                type: "object",
                properties: ["q": ToolProperty(type: "string", description: "query")],
                required: ["q"]
            )
        )
        let formatted = [def].toAnthropicFormat()
        #expect(formatted.count == 1)
        #expect(formatted[0]["name"] as? String == "test")
    }

    @Test("OpenAI format")
    func openAIFormat() {
        let def = ToolDefinition(
            name: "test",
            description: "desc",
            inputSchema: ToolInputSchema(
                type: "object",
                properties: ["q": ToolProperty(type: "string", description: "query")],
                required: ["q"]
            )
        )
        let formatted = [def].toOpenAIFormat()
        #expect(formatted.count == 1)
        #expect(formatted[0]["type"] as? String == "function")
    }
}
```

- [ ] **Step 8: Run full test suite**

Run: `swift test 2>&1 | tail -30`
Expected: All tests PASS. If any fail, fix them before committing.

- [ ] **Step 9: Commit**

```bash
git add -u
git add ShellmateTests/Tools/
git commit -m "refactor: wire ToolRegistry into ToolExecutor and ToolUseLoop, delete ToolDefinitions enum"
```

---

## Task 9: NaturalDateParser

**Files:**
- Create: `Shellmate/Services/Shared/NaturalDateParser.swift`
- Test: `ShellmateTests/Tools/Shared/NaturalDateParserTests.swift`

- [ ] **Step 1: Write NaturalDateParser tests**

```swift
import Testing
import Foundation
@testable import Shellmate

@Suite("NaturalDateParser")
struct NaturalDateParserTests {
    let parser = NaturalDateParser()

    // Use a fixed reference date for deterministic tests
    var referenceDate: Date {
        var cal = Calendar.current
        cal.timeZone = .current
        return cal.date(from: DateComponents(year: 2026, month: 3, day: 19, hour: 10, minute: 0))!
    }

    @Test("tomorrow")
    func tomorrow() {
        let result = parser.parseDate("tomorrow", relativeTo: referenceDate)
        #expect(result != nil)
        let cal = Calendar.current
        #expect(cal.component(.day, from: result!.date) == 20)
        #expect(!result!.hasExplicitTime)
    }

    @Test("tomorrow at 3pm")
    func tomorrowAt3pm() {
        let result = parser.parseDate("tomorrow at 3pm", relativeTo: referenceDate)
        #expect(result != nil)
        let cal = Calendar.current
        #expect(cal.component(.day, from: result!.date) == 20)
        #expect(cal.component(.hour, from: result!.date) == 15)
        #expect(result!.hasExplicitTime)
    }

    @Test("in 3 days")
    func inThreeDays() {
        let result = parser.parseDate("in 3 days", relativeTo: referenceDate)
        #expect(result != nil)
        let cal = Calendar.current
        #expect(cal.component(.day, from: result!.date) == 22)
    }

    @Test("morning maps to 9am")
    func morning() {
        let result = parser.parseDate("tomorrow morning", relativeTo: referenceDate)
        #expect(result != nil)
        let cal = Calendar.current
        #expect(cal.component(.hour, from: result!.date) == 9)
    }

    @Test("afternoon maps to 1pm")
    func afternoon() {
        let result = parser.parseDate("tomorrow afternoon", relativeTo: referenceDate)
        #expect(result != nil)
        let cal = Calendar.current
        #expect(cal.component(.hour, from: result!.date) == 13)
    }

    @Test("duration 30 minutes")
    func duration30min() {
        let result = parser.parseDuration("30 minutes")
        #expect(result != nil)
        #expect(result!.interval == 1800)
    }

    @Test("duration 1 hour")
    func duration1hour() {
        let result = parser.parseDuration("1 hour")
        #expect(result != nil)
        #expect(result!.interval == 3600)
    }

    @Test("nil for unparseable input")
    func unparseable() {
        let result = parser.parseDate("xyzzy garble", relativeTo: referenceDate)
        #expect(result == nil)
    }

    @Test("ISO 8601 fallback")
    func iso8601() {
        let result = parser.parseDate("2026-03-25T14:00:00", relativeTo: referenceDate)
        #expect(result != nil)
        let cal = Calendar.current
        #expect(cal.component(.day, from: result!.date) == 25)
        #expect(result!.hasExplicitTime)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter "NaturalDateParser" 2>&1 | tail -20`
Expected: Compilation error

- [ ] **Step 3: Implement NaturalDateParser**

```swift
// Shellmate/Services/Shared/NaturalDateParser.swift
import Foundation

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

    private static let colloquialTimes: [(pattern: String, hour: Int)] = [
        ("morning", 9), ("afternoon", 13), ("evening", 18), ("night", 20),
        ("noon", 12), ("midnight", 0),
    ]

    func parseDate(_ text: String, relativeTo: Date = .now) -> ParsedDate? {
        let lower = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let cal = Calendar.current

        // Try relative patterns first
        if let relative = parseRelative(lower, relativeTo: relativeTo, calendar: cal) {
            return relative
        }

        // Try NSDataDetector
        if let detected = parseWithDataDetector(text, relativeTo: relativeTo) {
            return detected
        }

        // Try ISO 8601 fallback
        if let iso = parseISO8601(text) {
            return iso
        }

        return nil
    }

    func parseRange(_ text: String, relativeTo: Date = .now) -> ParsedRange? {
        // Basic "from X to Y" pattern
        let lower = text.lowercased()
        guard let fromRange = lower.range(of: "from "),
              let toRange = lower.range(of: " to ") else { return nil }

        let startText = String(lower[fromRange.upperBound..<toRange.lowerBound])
        let endText = String(lower[toRange.upperBound...])

        guard let start = parseDate(startText, relativeTo: relativeTo),
              let end = parseDate(endText, relativeTo: relativeTo) else { return nil }

        return ParsedRange(start: start.date, end: end.date, source: text)
    }

    func parseDuration(_ text: String) -> ParsedDuration? {
        let lower = text.lowercased()

        if lower.contains("all day") {
            return ParsedDuration(interval: 86400, source: text)
        }

        let pattern = #"(\d+)\s*(minute|min|hour|hr|day|week)s?"#
        guard let match = lower.range(of: pattern, options: .regularExpression) else { return nil }
        let matched = String(lower[match])

        let numPattern = #"(\d+)"#
        guard let numMatch = matched.range(of: numPattern, options: .regularExpression) else { return nil }
        let num = Double(matched[numMatch]) ?? 0

        var seconds: TimeInterval = 0
        if matched.contains("minute") || matched.contains("min") {
            seconds = num * 60
        } else if matched.contains("hour") || matched.contains("hr") {
            seconds = num * 3600
        } else if matched.contains("day") {
            seconds = num * 86400
        } else if matched.contains("week") {
            seconds = num * 604800
        }

        return seconds > 0 ? ParsedDuration(interval: seconds, source: text) : nil
    }

    // MARK: - Private

    private func parseRelative(_ lower: String, relativeTo: Date, calendar cal: Calendar) -> ParsedDate? {
        var targetDate: Date?
        var hasExplicitTime = false

        // "tomorrow"
        if lower.contains("tomorrow") {
            targetDate = cal.date(byAdding: .day, value: 1, to: relativeTo)
        }

        // "in N days/hours/minutes"
        let inPattern = #"in\s+(\d+)\s+(day|hour|minute|min|week)s?"#
        if let match = lower.range(of: inPattern, options: .regularExpression) {
            let matched = String(lower[match])
            if let numMatch = matched.range(of: #"\d+"#, options: .regularExpression) {
                let num = Int(matched[numMatch]) ?? 0
                if matched.contains("day") {
                    targetDate = cal.date(byAdding: .day, value: num, to: relativeTo)
                } else if matched.contains("hour") {
                    targetDate = cal.date(byAdding: .hour, value: num, to: relativeTo)
                    hasExplicitTime = true
                } else if matched.contains("minute") || matched.contains("min") {
                    targetDate = cal.date(byAdding: .minute, value: num, to: relativeTo)
                    hasExplicitTime = true
                } else if matched.contains("week") {
                    targetDate = cal.date(byAdding: .weekOfYear, value: num, to: relativeTo)
                }
            }
        }

        // Apply colloquial time modifiers
        if var date = targetDate {
            for (pattern, hour) in Self.colloquialTimes {
                if lower.contains(pattern) {
                    date = cal.date(bySettingHour: hour, minute: 0, second: 0, of: date) ?? date
                    hasExplicitTime = true
                    break
                }
            }

            // "at Xpm/am" modifier
            let atPattern = #"at\s+(\d{1,2})\s*(am|pm|AM|PM)"#
            if let atMatch = lower.range(of: atPattern, options: .regularExpression) {
                let matched = String(lower[atMatch])
                if let hourMatch = matched.range(of: #"\d{1,2}"#, options: .regularExpression) {
                    var hour = Int(matched[hourMatch]) ?? 0
                    if matched.lowercased().contains("pm") && hour != 12 { hour += 12 }
                    if matched.lowercased().contains("am") && hour == 12 { hour = 0 }
                    date = cal.date(bySettingHour: hour, minute: 0, second: 0, of: date) ?? date
                    hasExplicitTime = true
                }
            }

            return ParsedDate(date: date, hasExplicitTime: hasExplicitTime, source: lower)
        }

        return nil
    }

    private func parseWithDataDetector(_ text: String, relativeTo: Date) -> ParsedDate? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else {
            return nil
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = detector.firstMatch(in: text, range: range),
              let date = match.date else { return nil }

        let hasTime = match.duration == 0 && match.timeZone != nil
        return ParsedDate(date: date, hasExplicitTime: hasTime, source: text)
    }

    private func parseISO8601(_ text: String) -> ParsedDate? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: text) {
            return ParsedDate(date: date, hasExplicitTime: true, source: text)
        }

        // Try without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: text) {
            return ParsedDate(date: date, hasExplicitTime: true, source: text)
        }

        // Try date-only or datetime without timezone
        let basic = ISO8601DateFormatter()
        basic.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime, .withDashSeparatorInDate]
        if let date = basic.date(from: text) {
            return ParsedDate(date: date, hasExplicitTime: true, source: text)
        }

        return nil
    }
}
```

- [ ] **Step 4: Run tests**

Run: `swift test --filter "NaturalDateParser" 2>&1 | tail -20`
Expected: All tests PASS

- [ ] **Step 5: Commit**

```bash
git add Shellmate/Services/Shared/NaturalDateParser.swift ShellmateTests/Tools/Shared/NaturalDateParserTests.swift
git commit -m "feat: add NaturalDateParser with relative dates, colloquial times, and ISO 8601 fallback"
```

---

## Task 10: App Bootstrap — Wire Registry at Launch

**Files:**
- Modify: `Shellmate/ShellmateApp.swift` (or wherever the app creates ToolUseLoop/ChatState)
- Modify: Any view or state that creates `ToolUseLoop` or `ToolExecutor`

- [ ] **Step 1: Find where ToolUseLoop is created**

Search for `ToolUseLoop()` in the codebase to find the creation site. It needs to receive the new `ToolExecutor` with injected registry.

- [ ] **Step 2: Create registry bootstrap**

Add a factory that creates the full registry with all providers:

```swift
// Add to wherever the app initializes services, or create a new file if needed.
// This wires: ShellService → ShellProvider, FilesProvider, WebProvider → ToolRegistry → ToolExecutor → ToolUseLoop

func makeToolExecutor() -> ToolExecutor {
    let shellService = ShellService()
    let registry = ToolRegistry()

    // Register providers synchronously — we need to await on actor methods
    // This should be called from an async context at app startup

    let confirmationHandler = ConfirmationUIHandler()
    let confirmationService = ConfirmationService(uiHandler: confirmationHandler)
    let permissionManager = PermissionManager()

    return ToolExecutor(
        registry: registry,
        confirmationService: confirmationService,
        permissionManager: permissionManager
    )
}

// Then register providers asynchronously:
// await executor.registry.register(ShellProvider(shellService: shellService))
// await executor.registry.register(FilesProvider())
// await executor.registry.register(WebProvider())
```

- [ ] **Step 3: Wire into ToolUseLoop creation**

Replace any `ToolUseLoop()` with `ToolUseLoop(executor: executor)`.

- [ ] **Step 4: Run full test suite**

Run: `swift test 2>&1 | tail -30`
Expected: All tests PASS

- [ ] **Step 5: Build and run the app**

Run: `swift build 2>&1 | tail -10`
Expected: Build succeeds. If running manually, verify a basic chat works (send a message, tool calls execute).

- [ ] **Step 6: Commit**

```bash
git add -u
git commit -m "feat: wire ToolRegistry bootstrap into app startup"
```

---

## Task 11: Settings UI — Capabilities Tab

**Files:**
- Create: `Shellmate/Views/Settings/Capabilities/CapabilitiesSettingsView.swift`

- [ ] **Step 1: Implement CapabilitiesSettingsView**

```swift
// Shellmate/Views/Settings/Capabilities/CapabilitiesSettingsView.swift
import SwiftUI

struct CapabilitiesSettingsView: View {
    @State private var enabledCategories: Set<String> = Set(ToolCategory.allCases.map(\.rawValue))
    @State private var permissionStatuses: [SystemPermission: PermissionManager.PermissionStatus] = [:]

    var body: some View {
        Form {
            Section("Permissions") {
                ForEach(SystemPermission.allCases, id: \.rawValue) { permission in
                    HStack {
                        Text(permission.displayName)
                        Spacer()
                        statusBadge(for: permissionStatuses[permission] ?? .notRequested)
                        Button("Open Settings") {
                            NSWorkspace.shared.open(permission.settingsPaneURL)
                        }
                        .buttonStyle(.borderless)
                        .font(.caption)
                    }
                }
            }

            Section("Tool Categories") {
                ForEach(ToolCategory.allCases, id: \.rawValue) { category in
                    Toggle(category.displayName, isOn: Binding(
                        get: { enabledCategories.contains(category.rawValue) },
                        set: { enabled in
                            if enabled {
                                enabledCategories.insert(category.rawValue)
                            } else {
                                enabledCategories.remove(category.rawValue)
                            }
                        }
                    ))
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Capabilities")
    }

    @ViewBuilder
    private func statusBadge(for status: PermissionManager.PermissionStatus) -> some View {
        switch status {
        case .granted:
            Text("Allowed").foregroundStyle(.green).font(.caption)
        case .denied:
            Text("Denied").foregroundStyle(.red).font(.caption)
        case .restricted:
            Text("Restricted").foregroundStyle(.orange).font(.caption)
        case .notRequested:
            Text("Not Asked").foregroundStyle(.secondary).font(.caption)
        }
    }
}
```

- [ ] **Step 2: Verify build**

Run: `swift build 2>&1 | tail -10`
Expected: Build succeeds

- [ ] **Step 3: Commit**

```bash
git add Shellmate/Views/Settings/Capabilities/
git commit -m "feat: add Capabilities settings tab with permissions dashboard and category toggles"
```

---

## Task 12: Confirmation Card UI

**Files:**
- Create: `Shellmate/Views/Chat/ConfirmationCardView.swift`

- [ ] **Step 1: Implement ConfirmationCardView**

```swift
// Shellmate/Views/Chat/ConfirmationCardView.swift
import SwiftUI

struct ConfirmationCardView: View {
    let request: ConfirmationRequest
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if request.tier == .destructive {
                Label("Warning", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.headline)
            }

            Text(request.description)
                .font(.body)

            if request.tier == .destructive {
                Text("This cannot be easily undone.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                Button("Approve") {
                    request.continuation.resume(returning: true); onDismiss()
                }
                .buttonStyle(.borderedProminent)

                Button("Deny") {
                    request.continuation.resume(returning: false); onDismiss()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(request.tier == .destructive ? Color.orange.opacity(0.5) : Color.clear, lineWidth: 1)
        )
    }
}
```

- [ ] **Step 2: Verify build**

Run: `swift build 2>&1 | tail -10`
Expected: Build succeeds

- [ ] **Step 3: Commit**

```bash
git add Shellmate/Views/Chat/ConfirmationCardView.swift
git commit -m "feat: add inline ConfirmationCardView for tool approval/denial"
```

---

## Task 13: Final Integration Test + Full Suite

- [ ] **Step 1: Run the full test suite**

Run: `swift test 2>&1 | tail -40`
Expected: All tests PASS

- [ ] **Step 2: Fix any remaining failures**

If tests fail, investigate and fix. Common issues:
- Old references to `ToolDefinitions.all` or `ToolDefinitions.shellExec` in tests
- Old references to static `ShellTool.execute` or `FileReadTool.execute`
- Missing imports or file references in Xcode project

- [ ] **Step 3: Run a clean build**

Run: `swift build -c release 2>&1 | tail -10`
Expected: Release build succeeds

- [ ] **Step 4: Commit any final fixes**

```bash
git add -u
git commit -m "fix: resolve remaining test and build issues from Phase 1 migration"
```

- [ ] **Step 5: Tag completion**

```bash
git tag phase1-foundation-complete
```
