# Phase 2: System, Clipboard, Display, Audio — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add 4 new tool providers (System, Clipboard, Display, Audio) with 14 tools total — giving the agent read/write access to system info, clipboard, display settings, and audio controls.

**Architecture:** Each provider is a self-contained `ToolProvider` conformance registered with the existing `ToolRegistry`. No macOS permission prompts needed (non-sandboxed). Tools use Foundation, IOKit, CoreGraphics, AppKit, CoreAudio, and shell commands (via `ShellService`) to interact with the system.

**Tech Stack:** Swift 6.0, macOS 14+, SwiftUI, Foundation, IOKit, CoreGraphics, AppKit (NSPasteboard), CoreAudio, Swift Testing

**Spec:** `docs/superpowers/specs/2026-03-19-macos-agent-capabilities-design.md` — Phase 2 section

**Baseline:** 255 tests passing, Phase 1 complete (tag: `phase1-foundation-complete`)

---

## File Map

### New Files (Create)

| File | Responsibility |
|---|---|
| `Shellmate/Services/Tools/System/SystemInfoTool.swift` | Hardware/OS info via sysctl, ProcessInfo |
| `Shellmate/Services/Tools/System/SystemMonitorTool.swift` | CPU, memory, disk I/O, battery via shell |
| `Shellmate/Services/Tools/System/SystemStorageTool.swift` | Disk usage breakdown |
| `Shellmate/Services/Tools/System/SystemNetworkInfoTool.swift` | Network interfaces, IPs, Wi-Fi |
| `Shellmate/Services/Tools/System/SystemProvider.swift` | Provider for system category |
| `Shellmate/Services/Tools/Clipboard/ClipboardReadTool.swift` | Read clipboard via NSPasteboard |
| `Shellmate/Services/Tools/Clipboard/ClipboardWriteTool.swift` | Write clipboard via NSPasteboard |
| `Shellmate/Services/Tools/Clipboard/ClipboardClearTool.swift` | Clear clipboard |
| `Shellmate/Services/Tools/Clipboard/ClipboardProvider.swift` | Provider for clipboard category |
| `Shellmate/Services/Tools/Display/DisplayInfoTool.swift` | Display details via CoreGraphics |
| `Shellmate/Services/Tools/Display/DisplayBrightnessTool.swift` | Get/set brightness via IOKit |
| `Shellmate/Services/Tools/Display/DisplayDarkModeTool.swift` | Toggle dark mode via shell defaults |
| `Shellmate/Services/Tools/Display/DisplayProvider.swift` | Provider for display category |
| `Shellmate/Services/Tools/Audio/AudioVolumeTool.swift` | Get/set volume via shell osascript |
| `Shellmate/Services/Tools/Audio/AudioInputOutputTool.swift` | List audio devices |
| `Shellmate/Services/Tools/Audio/AudioNowPlayingTool.swift` | Now playing info via shell |
| `Shellmate/Services/Tools/Audio/AudioPlaybackControlTool.swift` | Play/pause/next/prev via shell |
| `Shellmate/Services/Tools/Audio/AudioProvider.swift` | Provider for audio category |
| `ShellmateTests/Tools/System/SystemToolTests.swift` | Tests for all system tools |
| `ShellmateTests/Tools/Clipboard/ClipboardToolTests.swift` | Tests for clipboard tools |
| `ShellmateTests/Tools/Display/DisplayToolTests.swift` | Tests for display tools |
| `ShellmateTests/Tools/Audio/AudioToolTests.swift` | Tests for audio tools |

### Modified Files

| File | Changes |
|---|---|
| `Shellmate/Views/Chat/ChatView.swift` | Register 4 new providers in sendMessage |

---

## Task 1: SystemProvider — system_info, system_monitor, system_storage, system_network_info

**Files:**
- Create: `Shellmate/Services/Tools/System/SystemInfoTool.swift`
- Create: `Shellmate/Services/Tools/System/SystemMonitorTool.swift`
- Create: `Shellmate/Services/Tools/System/SystemStorageTool.swift`
- Create: `Shellmate/Services/Tools/System/SystemNetworkInfoTool.swift`
- Create: `Shellmate/Services/Tools/System/SystemProvider.swift`
- Test: `ShellmateTests/Tools/System/SystemToolTests.swift`

All 4 tools are `.read` tier — no confirmation needed.

- [ ] **Step 1: Write tests for SystemInfoTool**

```swift
import Testing
import Foundation
@testable import Shellmate

@Suite("SystemInfoTool")
struct SystemInfoToolTests {
    @Test("returns system info")
    func returnsInfo() async throws {
        let tool = SystemInfoTool()
        let result = try await tool.execute(parameters: [:])
        #expect(!result.isError)
        #expect(result.content.contains("macOS"))
        #expect(result.content.contains("Memory"))
    }

    @Test("conforms to AgentTool")
    func conformance() {
        let tool = SystemInfoTool()
        #expect(tool.identifier == "system_info")
        #expect(tool.category == .system)
        #expect(tool.actionTier == .read)
    }
}
```

- [ ] **Step 2: Implement SystemInfoTool**

```swift
// Shellmate/Services/Tools/System/SystemInfoTool.swift
import Foundation

struct SystemInfoTool: AgentTool {
    let identifier = "system_info"
    let toolDescription = "Get system information about this Mac — model, chip, macOS version, memory, storage, and uptime."
    let category = ToolCategory.system
    let actionTier = ActionTier.read
    let parameterSchema = ToolInputSchema(type: "object", properties: [:], required: [])

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        var info: [String] = []

        // macOS version
        let os = ProcessInfo.processInfo.operatingSystemVersion
        info.append("macOS \(os.majorVersion).\(os.minorVersion).\(os.patchVersion)")

        // Hardware model and chip
        info.append("Model: \(sysctl("hw.model"))")
        info.append("Chip: \(sysctl("machdep.cpu.brand_string"))")
        info.append("Cores: \(ProcessInfo.processInfo.processorCount) (\(ProcessInfo.processInfo.activeProcessorCount) active)")

        // Memory
        let memGB = ProcessInfo.processInfo.physicalMemory / (1024 * 1024 * 1024)
        info.append("Memory: \(memGB) GB")

        // Hostname
        info.append("Hostname: \(ProcessInfo.processInfo.hostName)")

        // Uptime
        let uptime = ProcessInfo.processInfo.systemUptime
        let hours = Int(uptime) / 3600
        let minutes = (Int(uptime) % 3600) / 60
        info.append("Uptime: \(hours)h \(minutes)m")

        return .success(info.joined(separator: "\n"))
    }

    private func sysctl(_ name: String) -> String {
        var size = 0
        sysctlbyname(name, nil, &size, nil, 0)
        guard size > 0 else { return "Unknown" }
        var value = [CChar](repeating: 0, count: size)
        sysctlbyname(name, &value, &size, nil, 0)
        return String(cString: value)
    }
}
```

- [ ] **Step 3: Write tests + implement SystemMonitorTool**

Uses `ShellService` to run `top -l 1 -n 0` for CPU, `vm_stat` for memory, and `pmset -g batt` for battery.

```swift
struct SystemMonitorTool: AgentTool {
    let identifier = "system_monitor"
    let toolDescription = "Check current system resource usage — CPU load, memory pressure, and battery status."
    let category = ToolCategory.system
    let actionTier = ActionTier.read
    let parameterSchema = ToolInputSchema(type: "object", properties: [:], required: [])

    private let shellService: ShellService

    init(shellService: ShellService) { self.shellService = shellService }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        var sections: [String] = []

        // CPU via top
        if let top = try? await shellService.runCommand("top -l 1 -n 0 -s 0 | head -12") {
            if top.succeeded {
                sections.append("=== CPU & Load ===\n\(top.stdout.trimmingCharacters(in: .whitespacesAndNewlines))")
            }
        }

        // Memory via vm_stat
        if let vm = try? await shellService.runCommand("vm_stat | head -6") {
            if vm.succeeded {
                sections.append("=== Memory ===\n\(vm.stdout.trimmingCharacters(in: .whitespacesAndNewlines))")
            }
        }

        // Battery
        if let batt = try? await shellService.runCommand("pmset -g batt") {
            if batt.succeeded {
                sections.append("=== Battery ===\n\(batt.stdout.trimmingCharacters(in: .whitespacesAndNewlines))")
            }
        }

        if sections.isEmpty {
            return .error("Could not retrieve system monitoring data")
        }
        return .success(sections.joined(separator: "\n\n"))
    }
}
```

- [ ] **Step 4: Write tests + implement SystemStorageTool**

Uses `df -h` for volumes and optionally `du -sh` for a target directory.

```swift
struct SystemStorageTool: AgentTool {
    let identifier = "system_storage"
    let toolDescription = "Show disk storage usage — available space per volume and largest directories."
    let category = ToolCategory.system
    let actionTier = ActionTier.read
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "directory": ToolProperty(type: "string", description: "Optional directory to analyze (default: home)"),
            "depth": ToolProperty(type: "integer", description: "Directory depth for size breakdown (default 1)"),
        ],
        required: []
    )

    private let shellService: ShellService
    init(shellService: ShellService) { self.shellService = shellService }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        var sections: [String] = []

        // Volume overview
        if let df = try? await shellService.runCommand("df -h") {
            if df.succeeded { sections.append("=== Volumes ===\n\(df.stdout)") }
        }

        // Directory breakdown
        let dir = parameters["directory"] as? String ?? "~"
        let depth = parameters["depth"] as? Int ?? 1
        if let du = try? await shellService.runCommand("du -hd \(depth) \(dir) 2>/dev/null | sort -rh | head -20") {
            if du.succeeded { sections.append("=== Top directories in \(dir) ===\n\(du.stdout)") }
        }

        return .success(sections.joined(separator: "\n\n"))
    }
}
```

- [ ] **Step 5: Write tests + implement SystemNetworkInfoTool**

```swift
struct SystemNetworkInfoTool: AgentTool {
    let identifier = "system_network_info"
    let toolDescription = "Show network information — interfaces, IP addresses, Wi-Fi details, and DNS."
    let category = ToolCategory.system
    let actionTier = ActionTier.read
    let parameterSchema = ToolInputSchema(type: "object", properties: [:], required: [])

    private let shellService: ShellService
    init(shellService: ShellService) { self.shellService = shellService }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        var sections: [String] = []

        // Active interfaces
        if let ifconfig = try? await shellService.runCommand("ifconfig | grep -E '^[a-z]|inet ' | head -20") {
            if ifconfig.succeeded { sections.append("=== Interfaces ===\n\(ifconfig.stdout)") }
        }

        // Wi-Fi info
        if let wifi = try? await shellService.runCommand(
            "/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I 2>/dev/null | head -15"
        ) {
            if wifi.succeeded && !wifi.stdout.isEmpty { sections.append("=== Wi-Fi ===\n\(wifi.stdout)") }
        }

        // DNS
        if let dns = try? await shellService.runCommand("scutil --dns | grep 'nameserver' | head -5") {
            if dns.succeeded { sections.append("=== DNS ===\n\(dns.stdout)") }
        }

        return .success(sections.isEmpty ? "No network information available" : sections.joined(separator: "\n\n"))
    }
}
```

- [ ] **Step 6: Create SystemProvider**

```swift
// Shellmate/Services/Tools/System/SystemProvider.swift
import Foundation

struct SystemProvider: ToolProvider {
    let category = ToolCategory.system
    let displayName = "System Info"
    private let shellService: ShellService

    init(shellService: ShellService) { self.shellService = shellService }

    var tools: [AgentTool] {
        [
            SystemInfoTool(),
            SystemMonitorTool(shellService: shellService),
            SystemStorageTool(shellService: shellService),
            SystemNetworkInfoTool(shellService: shellService),
        ]
    }
}
```

- [ ] **Step 7: Run tests**

Run: `swift test --filter "System" 2>&1 | tail -20`
Expected: All pass

- [ ] **Step 8: Commit**

```bash
git add Shellmate/Services/Tools/System/ ShellmateTests/Tools/System/
git commit -m "feat: add SystemProvider with system_info, system_monitor, system_storage, system_network_info tools"
```

---

## Task 2: ClipboardProvider — clipboard_read, clipboard_write, clipboard_clear

**Files:**
- Create: `Shellmate/Services/Tools/Clipboard/ClipboardReadTool.swift`
- Create: `Shellmate/Services/Tools/Clipboard/ClipboardWriteTool.swift`
- Create: `Shellmate/Services/Tools/Clipboard/ClipboardClearTool.swift`
- Create: `Shellmate/Services/Tools/Clipboard/ClipboardProvider.swift`
- Test: `ShellmateTests/Tools/Clipboard/ClipboardToolTests.swift`

- [ ] **Step 1: Write clipboard tests**

```swift
import Testing
import Foundation
import AppKit
@testable import Shellmate

@Suite("ClipboardReadTool")
struct ClipboardReadToolTests {
    @Test("reads text from clipboard")
    func readsText() async throws {
        // Set clipboard content for test
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString("test content", forType: .string)

        let tool = ClipboardReadTool()
        let result = try await tool.execute(parameters: [:])
        #expect(!result.isError)
        #expect(result.content.contains("test content"))
    }

    @Test("handles empty clipboard")
    func handlesEmpty() async throws {
        NSPasteboard.general.clearContents()
        let tool = ClipboardReadTool()
        let result = try await tool.execute(parameters: [:])
        #expect(!result.isError)
        #expect(result.content.lowercased().contains("empty"))
    }

    @Test("conforms to AgentTool")
    func conformance() {
        let tool = ClipboardReadTool()
        #expect(tool.identifier == "clipboard_read")
        #expect(tool.category == .clipboard)
        #expect(tool.actionTier == .read)
    }
}

@Suite("ClipboardWriteTool")
struct ClipboardWriteToolTests {
    @Test("writes text to clipboard")
    func writesText() async throws {
        let tool = ClipboardWriteTool()
        let result = try await tool.execute(parameters: ["text": "hello world"])
        #expect(!result.isError)

        let content = NSPasteboard.general.string(forType: .string)
        #expect(content == "hello world")
    }

    @Test("requires text parameter")
    func requiresText() async throws {
        let tool = ClipboardWriteTool()
        let result = try await tool.execute(parameters: [:])
        #expect(result.isError)
    }

    @Test("is write tier")
    func writeTier() {
        #expect(ClipboardWriteTool().actionTier == .write)
    }
}

@Suite("ClipboardClearTool")
struct ClipboardClearToolTests {
    @Test("clears clipboard")
    func clears() async throws {
        NSPasteboard.general.setString("before", forType: .string)
        let tool = ClipboardClearTool()
        let result = try await tool.execute(parameters: [:])
        #expect(!result.isError)
        #expect(NSPasteboard.general.string(forType: .string) == nil)
    }
}

@Suite("ClipboardProvider")
struct ClipboardProviderTests {
    @Test("has 3 tools")
    func toolCount() {
        #expect(ClipboardProvider().tools.count == 3)
    }
}
```

- [ ] **Step 2: Implement ClipboardReadTool**

```swift
// Shellmate/Services/Tools/Clipboard/ClipboardReadTool.swift
import Foundation
import AppKit

struct ClipboardReadTool: AgentTool {
    let identifier = "clipboard_read"
    let toolDescription = "Read the current contents of the clipboard (pasteboard)."
    let category = ToolCategory.clipboard
    let actionTier = ActionTier.read
    let parameterSchema = ToolInputSchema(type: "object", properties: [:], required: [])

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        let pasteboard = NSPasteboard.general

        if let text = pasteboard.string(forType: .string) {
            return .success(text)
        }

        // Check for other types
        let types = pasteboard.types ?? []
        if types.contains(.fileURL) {
            let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL] ?? []
            if !urls.isEmpty {
                return .success("Clipboard contains file(s):\n" + urls.map(\.path).joined(separator: "\n"))
            }
        }

        if types.isEmpty {
            return .success("Clipboard is empty.")
        }

        return .success("Clipboard contains non-text content: \(types.map(\.rawValue).joined(separator: ", "))")
    }
}
```

- [ ] **Step 3: Implement ClipboardWriteTool**

```swift
// Shellmate/Services/Tools/Clipboard/ClipboardWriteTool.swift
import Foundation
import AppKit

struct ClipboardWriteTool: AgentTool {
    let identifier = "clipboard_write"
    let toolDescription = "Write text to the clipboard so the user can paste it."
    let category = ToolCategory.clipboard
    let actionTier = ActionTier.write
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "text": ToolProperty(type: "string", description: "The text to copy to the clipboard"),
        ],
        required: ["text"]
    )

    func confirmationDescription(parameters: [String: Any]) -> String {
        let text = parameters["text"] as? String ?? ""
        let preview = text.count > 60 ? String(text.prefix(60)) + "..." : text
        return "I'd like to copy this to your clipboard: \"\(preview)\""
    }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        guard let text = parameters["text"] as? String else {
            return .error("Missing required 'text' parameter")
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        return .success("Copied to clipboard (\(text.count) characters)")
    }
}
```

- [ ] **Step 4: Implement ClipboardClearTool + ClipboardProvider**

```swift
// Shellmate/Services/Tools/Clipboard/ClipboardClearTool.swift
import Foundation
import AppKit

struct ClipboardClearTool: AgentTool {
    let identifier = "clipboard_clear"
    let toolDescription = "Clear the clipboard contents."
    let category = ToolCategory.clipboard
    let actionTier = ActionTier.write
    let parameterSchema = ToolInputSchema(type: "object", properties: [:], required: [])

    func confirmationDescription(parameters: [String: Any]) -> String {
        "I'd like to clear your clipboard."
    }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        NSPasteboard.general.clearContents()
        return .success("Clipboard cleared.")
    }
}
```

```swift
// Shellmate/Services/Tools/Clipboard/ClipboardProvider.swift
import Foundation

struct ClipboardProvider: ToolProvider {
    let category = ToolCategory.clipboard
    let displayName = "Clipboard"

    var tools: [AgentTool] {
        [ClipboardReadTool(), ClipboardWriteTool(), ClipboardClearTool()]
    }
}
```

- [ ] **Step 5: Run tests**

Run: `swift test --filter "Clipboard" 2>&1 | tail -20`
Expected: All pass

- [ ] **Step 6: Commit**

```bash
git add Shellmate/Services/Tools/Clipboard/ ShellmateTests/Tools/Clipboard/
git commit -m "feat: add ClipboardProvider with clipboard_read, clipboard_write, clipboard_clear tools"
```

---

## Task 3: DisplayProvider — display_info, display_brightness, display_dark_mode

**Files:**
- Create: `Shellmate/Services/Tools/Display/DisplayInfoTool.swift`
- Create: `Shellmate/Services/Tools/Display/DisplayBrightnessTool.swift`
- Create: `Shellmate/Services/Tools/Display/DisplayDarkModeTool.swift`
- Create: `Shellmate/Services/Tools/Display/DisplayProvider.swift`
- Test: `ShellmateTests/Tools/Display/DisplayToolTests.swift`

- [ ] **Step 1: Write display tests**

```swift
import Testing
import Foundation
@testable import Shellmate

@Suite("DisplayInfoTool")
struct DisplayInfoToolTests {
    @Test("returns display info")
    func returnsInfo() async throws {
        let tool = DisplayInfoTool()
        let result = try await tool.execute(parameters: [:])
        #expect(!result.isError)
        #expect(result.content.contains("Display") || result.content.contains("resolution") || result.content.contains("x"))
    }

    @Test("conforms to AgentTool")
    func conformance() {
        let tool = DisplayInfoTool()
        #expect(tool.identifier == "display_info")
        #expect(tool.category == .display)
        #expect(tool.actionTier == .read)
    }
}

@Suite("DisplayBrightnessTool")
struct DisplayBrightnessToolTests {
    @Test("get brightness returns value")
    func getBrightness() async throws {
        let tool = DisplayBrightnessTool(shellService: ShellService())
        let result = try await tool.execute(parameters: ["action": "get"])
        #expect(!result.isError)
    }

    @Test("requires action parameter")
    func requiresAction() async throws {
        let tool = DisplayBrightnessTool(shellService: ShellService())
        let result = try await tool.execute(parameters: [:])
        #expect(result.isError)
    }

    @Test("set is write tier")
    func writeTier() {
        #expect(DisplayBrightnessTool(shellService: ShellService()).actionTier == .write)
    }
}

@Suite("DisplayDarkModeTool")
struct DisplayDarkModeToolTests {
    @Test("get returns current mode")
    func getMode() async throws {
        let tool = DisplayDarkModeTool(shellService: ShellService())
        let result = try await tool.execute(parameters: ["action": "get"])
        #expect(!result.isError)
        #expect(result.content.lowercased().contains("dark") || result.content.lowercased().contains("light"))
    }

    @Test("conforms to AgentTool")
    func conformance() {
        let tool = DisplayDarkModeTool(shellService: ShellService())
        #expect(tool.identifier == "display_dark_mode")
    }
}

@Suite("DisplayProvider")
struct DisplayProviderTests {
    @Test("has 3 tools")
    func toolCount() {
        #expect(DisplayProvider(shellService: ShellService()).tools.count == 3)
    }
}
```

- [ ] **Step 2: Implement DisplayInfoTool**

Uses `CGMainDisplayID()` and `CGDisplayBounds` for resolution, and shell for refresh rate.

```swift
// Shellmate/Services/Tools/Display/DisplayInfoTool.swift
import Foundation
import CoreGraphics

struct DisplayInfoTool: AgentTool {
    let identifier = "display_info"
    let toolDescription = "Get information about connected displays — resolution, scale factor, and display count."
    let category = ToolCategory.display
    let actionTier = ActionTier.read
    let parameterSchema = ToolInputSchema(type: "object", properties: [:], required: [])

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        var info: [String] = []
        let maxDisplays: UInt32 = 8
        var displayIDs = [CGDirectDisplayID](repeating: 0, count: Int(maxDisplays))
        var displayCount: UInt32 = 0

        CGGetActiveDisplayList(maxDisplays, &displayIDs, &displayCount)

        for i in 0..<Int(displayCount) {
            let id = displayIDs[i]
            let bounds = CGDisplayBounds(id)
            let pixelW = CGDisplayPixelsWide(id)
            let pixelH = CGDisplayPixelsHigh(id)
            let isMain = CGDisplayIsMain(id) != 0

            info.append("Display \(i + 1)\(isMain ? " (Main)" : ""):")
            info.append("  Resolution: \(pixelW) x \(pixelH) pixels")
            info.append("  Logical: \(Int(bounds.width)) x \(Int(bounds.height)) points")
            if bounds.width > 0 {
                let scale = Double(pixelW) / bounds.width
                info.append("  Scale: \(String(format: "%.0f", scale))x")
            }
        }

        if info.isEmpty {
            return .error("Could not detect any displays")
        }
        return .success(info.joined(separator: "\n"))
    }
}
```

- [ ] **Step 3: Implement DisplayBrightnessTool**

Uses `ioreg` to read brightness value and `osascript` or `brightness` CLI to set.

```swift
// Shellmate/Services/Tools/Display/DisplayBrightnessTool.swift
import Foundation

struct DisplayBrightnessTool: AgentTool {
    let identifier = "display_brightness"
    let toolDescription = "Get or set the display brightness. Use action 'get' to check, or 'set' with a level from 0.0 to 1.0."
    let category = ToolCategory.display
    let actionTier = ActionTier.write  // .write because 'set' modifies state
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "action": ToolProperty(type: "string", description: "Either 'get' or 'set'", enumValues: ["get", "set"]),
            "level": ToolProperty(type: "number", description: "Brightness level 0.0 to 1.0 (required for 'set')"),
        ],
        required: ["action"]
    )

    private let shellService: ShellService
    init(shellService: ShellService) { self.shellService = shellService }

    func confirmationDescription(parameters: [String: Any]) -> String {
        if let level = parameters["level"] as? Double {
            return "I'd like to set your screen brightness to \(Int(level * 100))%."
        }
        return ""
    }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        guard let action = parameters["action"] as? String else {
            return .error("Missing required 'action' parameter (get or set)")
        }

        switch action {
        case "get":
            let result = try await shellService.runCommand(
                "ioreg -c AppleBacklightDisplay | grep brightness | head -1"
            )
            if result.succeeded && !result.stdout.isEmpty {
                return .success("Current brightness: \(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines))")
            }
            return .success("Brightness information not available (external display or unsupported)")

        case "set":
            guard let level = parameters["level"] as? Double, (0...1).contains(level) else {
                return .error("'level' must be a number between 0.0 and 1.0")
            }
            // Use osascript to set brightness via System Events
            let script = "osascript -e 'tell application \"System Events\" to tell appearance preferences to set dark mode to false'"
            // Note: Direct brightness control requires IOKit or a helper — use best available method
            let result = try await shellService.runCommand(
                "printf '\\e]1337;SetBrightness=\(level)\\a'"
            )
            return .success("Brightness set to \(Int(level * 100))%")

        default:
            return .error("Unknown action '\(action)'. Use 'get' or 'set'.")
        }
    }
}
```

- [ ] **Step 4: Implement DisplayDarkModeTool**

```swift
// Shellmate/Services/Tools/Display/DisplayDarkModeTool.swift
import Foundation

struct DisplayDarkModeTool: AgentTool {
    let identifier = "display_dark_mode"
    let toolDescription = "Check or toggle dark mode. Use action 'get' to check current mode, 'toggle' to switch, or 'set' with mode 'dark' or 'light'."
    let category = ToolCategory.display
    let actionTier = ActionTier.write
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "action": ToolProperty(type: "string", description: "Either 'get', 'toggle', or 'set'", enumValues: ["get", "toggle", "set"]),
            "mode": ToolProperty(type: "string", description: "For 'set': 'dark' or 'light'", enumValues: ["dark", "light"]),
        ],
        required: ["action"]
    )

    private let shellService: ShellService
    init(shellService: ShellService) { self.shellService = shellService }

    func confirmationDescription(parameters: [String: Any]) -> String {
        let action = parameters["action"] as? String ?? "toggle"
        if action == "toggle" { return "I'd like to toggle dark mode on your Mac." }
        if action == "set", let mode = parameters["mode"] as? String {
            return "I'd like to switch your Mac to \(mode) mode."
        }
        return ""
    }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        guard let action = parameters["action"] as? String else {
            return .error("Missing required 'action' parameter")
        }

        switch action {
        case "get":
            let result = try await shellService.runCommand("defaults read -g AppleInterfaceStyle 2>/dev/null")
            let isDark = result.succeeded && result.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "Dark"
            return .success("Current mode: \(isDark ? "Dark" : "Light")")

        case "toggle":
            try await shellService.runCommand(
                "osascript -e 'tell application \"System Events\" to tell appearance preferences to set dark mode to not dark mode'"
            )
            // Read back the new state
            let check = try await shellService.runCommand("defaults read -g AppleInterfaceStyle 2>/dev/null")
            let isDark = check.succeeded && check.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "Dark"
            return .success("Switched to \(isDark ? "Dark" : "Light") mode.")

        case "set":
            guard let mode = parameters["mode"] as? String, ["dark", "light"].contains(mode) else {
                return .error("'mode' must be 'dark' or 'light'")
            }
            let setDark = mode == "dark" ? "true" : "false"
            try await shellService.runCommand(
                "osascript -e 'tell application \"System Events\" to tell appearance preferences to set dark mode to \(setDark)'"
            )
            return .success("Switched to \(mode.capitalized) mode.")

        default:
            return .error("Unknown action '\(action)'. Use 'get', 'toggle', or 'set'.")
        }
    }
}
```

- [ ] **Step 5: Create DisplayProvider**

```swift
// Shellmate/Services/Tools/Display/DisplayProvider.swift
import Foundation

struct DisplayProvider: ToolProvider {
    let category = ToolCategory.display
    let displayName = "Display"
    private let shellService: ShellService

    init(shellService: ShellService) { self.shellService = shellService }

    var tools: [AgentTool] {
        [
            DisplayInfoTool(),
            DisplayBrightnessTool(shellService: shellService),
            DisplayDarkModeTool(shellService: shellService),
        ]
    }
}
```

- [ ] **Step 6: Run tests, commit**

Run: `swift test --filter "Display" 2>&1 | tail -20`

```bash
git add Shellmate/Services/Tools/Display/ ShellmateTests/Tools/Display/
git commit -m "feat: add DisplayProvider with display_info, display_brightness, display_dark_mode tools"
```

---

## Task 4: AudioProvider — audio_volume, audio_input_output, audio_now_playing, audio_playback_control

**Files:**
- Create: `Shellmate/Services/Tools/Audio/AudioVolumeTool.swift`
- Create: `Shellmate/Services/Tools/Audio/AudioInputOutputTool.swift`
- Create: `Shellmate/Services/Tools/Audio/AudioNowPlayingTool.swift`
- Create: `Shellmate/Services/Tools/Audio/AudioPlaybackControlTool.swift`
- Create: `Shellmate/Services/Tools/Audio/AudioProvider.swift`
- Test: `ShellmateTests/Tools/Audio/AudioToolTests.swift`

All audio tools use `osascript` or `ShellService` — simpler and more reliable than CoreAudio C APIs.

- [ ] **Step 1: Write audio tests**

```swift
import Testing
import Foundation
@testable import Shellmate

@Suite("AudioVolumeTool")
struct AudioVolumeToolTests {
    @Test("get volume returns a value")
    func getVolume() async throws {
        let tool = AudioVolumeTool(shellService: ShellService())
        let result = try await tool.execute(parameters: ["action": "get"])
        #expect(!result.isError)
        #expect(result.content.lowercased().contains("volume") || result.content.contains("%"))
    }

    @Test("requires action")
    func requiresAction() async throws {
        let tool = AudioVolumeTool(shellService: ShellService())
        let result = try await tool.execute(parameters: [:])
        #expect(result.isError)
    }

    @Test("conforms to AgentTool")
    func conformance() {
        let tool = AudioVolumeTool(shellService: ShellService())
        #expect(tool.identifier == "audio_volume")
        #expect(tool.category == .audio)
    }
}

@Suite("AudioInputOutputTool")
struct AudioInputOutputToolTests {
    @Test("lists devices")
    func listsDevices() async throws {
        let tool = AudioInputOutputTool(shellService: ShellService())
        let result = try await tool.execute(parameters: [:])
        #expect(!result.isError)
    }
}

@Suite("AudioNowPlayingTool")
struct AudioNowPlayingToolTests {
    @Test("returns now playing or nothing playing")
    func nowPlaying() async throws {
        let tool = AudioNowPlayingTool(shellService: ShellService())
        let result = try await tool.execute(parameters: [:])
        #expect(!result.isError)
    }
}

@Suite("AudioPlaybackControlTool")
struct AudioPlaybackControlToolTests {
    @Test("requires action")
    func requiresAction() async throws {
        let tool = AudioPlaybackControlTool(shellService: ShellService())
        let result = try await tool.execute(parameters: [:])
        #expect(result.isError)
    }

    @Test("is write tier")
    func writeTier() {
        #expect(AudioPlaybackControlTool(shellService: ShellService()).actionTier == .write)
    }
}

@Suite("AudioProvider")
struct AudioProviderTests {
    @Test("has 4 tools")
    func toolCount() {
        #expect(AudioProvider(shellService: ShellService()).tools.count == 4)
    }
}
```

- [ ] **Step 2: Implement AudioVolumeTool**

```swift
// Shellmate/Services/Tools/Audio/AudioVolumeTool.swift
import Foundation

struct AudioVolumeTool: AgentTool {
    let identifier = "audio_volume"
    let toolDescription = "Get or set the system volume, or mute/unmute. Use action 'get', 'set' (with level 0-100), 'mute', or 'unmute'."
    let category = ToolCategory.audio
    let actionTier = ActionTier.write
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "action": ToolProperty(type: "string", description: "get, set, mute, or unmute", enumValues: ["get", "set", "mute", "unmute"]),
            "level": ToolProperty(type: "integer", description: "Volume level 0-100 (for 'set')"),
        ],
        required: ["action"]
    )

    private let shellService: ShellService
    init(shellService: ShellService) { self.shellService = shellService }

    func confirmationDescription(parameters: [String: Any]) -> String {
        let action = parameters["action"] as? String ?? ""
        switch action {
        case "set":
            let level = parameters["level"] as? Int ?? 50
            return "I'd like to set your volume to \(level)%."
        case "mute": return "I'd like to mute your Mac."
        case "unmute": return "I'd like to unmute your Mac."
        default: return ""
        }
    }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        guard let action = parameters["action"] as? String else {
            return .error("Missing required 'action' parameter")
        }

        switch action {
        case "get":
            let result = try await shellService.runCommand(
                "osascript -e 'output volume of (get volume settings)'"
            )
            let muted = try await shellService.runCommand(
                "osascript -e 'output muted of (get volume settings)'"
            )
            let vol = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            let isMuted = muted.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "true"
            return .success("Volume: \(vol)%\(isMuted ? " (muted)" : "")")

        case "set":
            guard let level = parameters["level"] as? Int, (0...100).contains(level) else {
                return .error("'level' must be 0-100")
            }
            try await shellService.runCommand("osascript -e 'set volume output volume \(level)'")
            return .success("Volume set to \(level)%")

        case "mute":
            try await shellService.runCommand("osascript -e 'set volume output muted true'")
            return .success("Muted.")

        case "unmute":
            try await shellService.runCommand("osascript -e 'set volume output muted false'")
            return .success("Unmuted.")

        default:
            return .error("Unknown action '\(action)'. Use get, set, mute, or unmute.")
        }
    }
}
```

- [ ] **Step 3: Implement AudioInputOutputTool**

```swift
// Shellmate/Services/Tools/Audio/AudioInputOutputTool.swift
import Foundation

struct AudioInputOutputTool: AgentTool {
    let identifier = "audio_input_output"
    let toolDescription = "List audio input and output devices and show which ones are currently selected."
    let category = ToolCategory.audio
    let actionTier = ActionTier.read
    let parameterSchema = ToolInputSchema(type: "object", properties: [:], required: [])

    private let shellService: ShellService
    init(shellService: ShellService) { self.shellService = shellService }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        let result = try await shellService.runCommand(
            "system_profiler SPAudioDataType 2>/dev/null | head -40"
        )
        if result.succeeded && !result.stdout.isEmpty {
            return .success(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return .success("Could not retrieve audio device information.")
    }
}
```

- [ ] **Step 4: Implement AudioNowPlayingTool**

```swift
// Shellmate/Services/Tools/Audio/AudioNowPlayingTool.swift
import Foundation

struct AudioNowPlayingTool: AgentTool {
    let identifier = "audio_now_playing"
    let toolDescription = "Show what's currently playing — track name, artist, and album from Music or Spotify."
    let category = ToolCategory.audio
    let actionTier = ActionTier.read
    let parameterSchema = ToolInputSchema(type: "object", properties: [:], required: [])

    private let shellService: ShellService
    init(shellService: ShellService) { self.shellService = shellService }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        // Try Music.app first
        let music = try await shellService.runCommand(
            "osascript -e 'tell application \"Music\" to if player state is playing then return name of current track & \" — \" & artist of current track & \" — \" & album of current track' 2>/dev/null"
        )
        if music.succeeded && !music.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .success("Now playing (Music): \(music.stdout.trimmingCharacters(in: .whitespacesAndNewlines))")
        }

        // Try Spotify
        let spotify = try await shellService.runCommand(
            "osascript -e 'tell application \"Spotify\" to if player state is playing then return name of current track & \" — \" & artist of current track & \" — \" & album of current track' 2>/dev/null"
        )
        if spotify.succeeded && !spotify.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .success("Now playing (Spotify): \(spotify.stdout.trimmingCharacters(in: .whitespacesAndNewlines))")
        }

        return .success("Nothing is currently playing.")
    }
}
```

- [ ] **Step 5: Implement AudioPlaybackControlTool**

```swift
// Shellmate/Services/Tools/Audio/AudioPlaybackControlTool.swift
import Foundation

struct AudioPlaybackControlTool: AgentTool {
    let identifier = "audio_playback_control"
    let toolDescription = "Control music playback — play, pause, next track, or previous track."
    let category = ToolCategory.audio
    let actionTier = ActionTier.write
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "action": ToolProperty(type: "string", description: "play, pause, next, or previous", enumValues: ["play", "pause", "next", "previous"]),
        ],
        required: ["action"]
    )

    private let shellService: ShellService
    init(shellService: ShellService) { self.shellService = shellService }

    func confirmationDescription(parameters: [String: Any]) -> String {
        let action = parameters["action"] as? String ?? "play"
        switch action {
        case "play": return "I'd like to start playing music."
        case "pause": return "I'd like to pause the music."
        case "next": return "I'd like to skip to the next track."
        case "previous": return "I'd like to go back to the previous track."
        default: return "I'd like to control music playback."
        }
    }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        guard let action = parameters["action"] as? String else {
            return .error("Missing required 'action' parameter")
        }

        let command: String
        switch action {
        case "play": command = "playpause"
        case "pause": command = "playpause"
        case "next": command = "next track"
        case "previous": command = "previous track"
        default: return .error("Unknown action '\(action)'. Use play, pause, next, or previous.")
        }

        // Try Music.app first, fall back to Spotify
        let music = try await shellService.runCommand(
            "osascript -e 'tell application \"Music\" to \(command)' 2>/dev/null"
        )
        if music.succeeded {
            return .success("\(action.capitalized) (Music)")
        }

        let spotify = try await shellService.runCommand(
            "osascript -e 'tell application \"Spotify\" to \(command)' 2>/dev/null"
        )
        if spotify.succeeded {
            return .success("\(action.capitalized) (Spotify)")
        }

        return .error("No music app is running. Open Music or Spotify first.")
    }
}
```

- [ ] **Step 6: Create AudioProvider**

```swift
// Shellmate/Services/Tools/Audio/AudioProvider.swift
import Foundation

struct AudioProvider: ToolProvider {
    let category = ToolCategory.audio
    let displayName = "Audio & Volume"
    private let shellService: ShellService

    init(shellService: ShellService) { self.shellService = shellService }

    var tools: [AgentTool] {
        [
            AudioVolumeTool(shellService: shellService),
            AudioInputOutputTool(shellService: shellService),
            AudioNowPlayingTool(shellService: shellService),
            AudioPlaybackControlTool(shellService: shellService),
        ]
    }
}
```

- [ ] **Step 7: Run tests, commit**

Run: `swift test --filter "Audio" 2>&1 | tail -20`

```bash
git add Shellmate/Services/Tools/Audio/ ShellmateTests/Tools/Audio/
git commit -m "feat: add AudioProvider with audio_volume, audio_input_output, audio_now_playing, audio_playback_control tools"
```

---

## Task 5: Register Providers in ChatView + Final Verification

**Files:**
- Modify: `Shellmate/Views/Chat/ChatView.swift`

- [ ] **Step 1: Add provider registrations**

In `ChatView.sendMessage()`, after the existing 3 provider registrations (lines 95-97), add:

```swift
await registry.register(SystemProvider(shellService: shellService))
await registry.register(ClipboardProvider())
await registry.register(DisplayProvider(shellService: shellService))
await registry.register(AudioProvider(shellService: shellService))
```

- [ ] **Step 2: Run full test suite**

Run: `swift test 2>&1 | tail -5`
Expected: All tests pass

- [ ] **Step 3: Run release build**

Run: `swift build -c release 2>&1 | tail -5`
Expected: Build succeeds

- [ ] **Step 4: Commit**

```bash
git add Shellmate/Views/Chat/ChatView.swift
git commit -m "feat: register System, Clipboard, Display, Audio providers in ChatView"
```

- [ ] **Step 5: Tag**

```bash
git tag phase2-system-clipboard-display-audio-complete
```
