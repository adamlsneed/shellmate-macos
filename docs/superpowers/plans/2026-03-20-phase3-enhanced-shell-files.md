# Phase 3: Enhanced Shell & Files — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Expand `ShellProvider` with 6 new tools (shell scripting, environment management, Homebrew/Xcode CLI bootstrapping) and `FilesProvider` with 9 new tools (search, move, copy, delete, compress, open, Finder integration) — bringing total tools from 20 to 35.

**Architecture:** New tools are added to the existing `ShellProvider` and `FilesProvider`. Shell tools depend on `ShellService`. File tools use `Foundation`/`FileManager` directly. `files_delete` defaults to Trash via `NSWorkspace.recyclePromise`. Search uses Spotlight via `NSMetadataQuery` or `mdfind` shell command.

**Tech Stack:** Swift 6.0, macOS 14+, Foundation, AppKit (NSWorkspace), Swift Testing

**Spec:** `docs/superpowers/specs/2026-03-19-macos-agent-capabilities-design.md` — Phase 3 section

**Baseline:** 308 tests passing, Phase 2 complete (tag: `phase2-system-clipboard-display-audio-complete`)

---

## File Map

### New Files (Create)

| File | Responsibility |
|---|---|
| `Shellmate/Services/Tools/Shell/ShellScriptTool.swift` | Execute multi-line shell scripts (.write, always confirm) |
| `Shellmate/Services/Tools/Shell/ShellEnvironmentTool.swift` | Show shell environment variables |
| `Shellmate/Services/Tools/Shell/ShellHistoryTool.swift` | Show agent's command history this session |
| `Shellmate/Services/Tools/Shell/EnvCheckPathTool.swift` | Check if a command exists on PATH |
| `Shellmate/Services/Tools/Shell/SetupHomebrewTool.swift` | Check/install Homebrew |
| `Shellmate/Services/Tools/Shell/SetupDeveloperToolsTool.swift` | Check/install Xcode CLI Tools |
| `Shellmate/Services/Tools/Files/FilesSearchTool.swift` | Spotlight search via mdfind |
| `Shellmate/Services/Tools/Files/FilesMoveTool.swift` | Move/rename files |
| `Shellmate/Services/Tools/Files/FilesCopyTool.swift` | Copy files/directories |
| `Shellmate/Services/Tools/Files/FilesDeleteTool.swift` | Move to Trash (default, .destructive) |
| `Shellmate/Services/Tools/Files/FilesCompressTool.swift` | Create zip archives |
| `Shellmate/Services/Tools/Files/FilesDecompressTool.swift` | Extract archives |
| `Shellmate/Services/Tools/Files/FilesDiskUsageTool.swift` | Directory size breakdown |
| `Shellmate/Services/Tools/Files/FilesOpenTool.swift` | Open file with default app |
| `Shellmate/Services/Tools/Files/FilesRevealInFinderTool.swift` | Reveal in Finder |
| `ShellmateTests/Tools/Shell/ShellEnhancedToolTests.swift` | Tests for 6 new shell tools |
| `ShellmateTests/Tools/Files/FilesEnhancedToolTests.swift` | Tests for 9 new file tools |

### Modified Files

| File | Changes |
|---|---|
| `Shellmate/Services/Tools/Shell/ShellProvider.swift` | Add 6 new tools to `tools` array |
| `Shellmate/Services/Tools/Files/FilesProvider.swift` | Add ShellService dependency, 9 new tools |

---

## Task 1: Enhanced Shell Tools (6 tools)

**Files:**
- Create: `Shellmate/Services/Tools/Shell/ShellScriptTool.swift`
- Create: `Shellmate/Services/Tools/Shell/ShellEnvironmentTool.swift`
- Create: `Shellmate/Services/Tools/Shell/ShellHistoryTool.swift`
- Create: `Shellmate/Services/Tools/Shell/EnvCheckPathTool.swift`
- Create: `Shellmate/Services/Tools/Shell/SetupHomebrewTool.swift`
- Create: `Shellmate/Services/Tools/Shell/SetupDeveloperToolsTool.swift`
- Modify: `Shellmate/Services/Tools/Shell/ShellProvider.swift`
- Test: `ShellmateTests/Tools/Shell/ShellEnhancedToolTests.swift`

### ShellScriptTool (identifier: "shell_script", .write tier ALWAYS)

Writes a multi-line script to a temp file, executes via `/bin/zsh`, cleans up. **Always requires confirmation** — shows the full script to the user.

```swift
struct ShellScriptTool: AgentTool {
    let identifier = "shell_script"
    let toolDescription = "Execute a multi-line shell script. The script will be shown to you for approval before running."
    let category = ToolCategory.shell
    let actionTier = ActionTier.write
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "script": ToolProperty(type: "string", description: "The shell script to execute"),
            "interpreter": ToolProperty(type: "string", description: "Shell interpreter (default: /bin/zsh)"),
        ],
        required: ["script"]
    )

    private let shellService: ShellService
    init(service: ShellService) { self.shellService = service }

    func confirmationDescription(parameters: [String: Any]) -> String {
        let script = parameters["script"] as? String ?? ""
        let preview = script.count > 200 ? String(script.prefix(200)) + "\n..." : script
        return "I'd like to run this script:\n\n\(preview)"
    }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        guard let script = parameters["script"] as? String else {
            return .error("Missing required 'script' parameter")
        }
        let interpreter = parameters["interpreter"] as? String ?? "/bin/zsh"

        // Write to temp file
        let tmpDir = FileManager.default.temporaryDirectory
        let scriptFile = tmpDir.appendingPathComponent("shellmate-script-\(UUID().uuidString).sh")

        do {
            try script.write(to: scriptFile, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: scriptFile.path)

            let result = try await shellService.run(
                executable: interpreter,
                arguments: [scriptFile.path]
            )

            // Cleanup
            try? FileManager.default.removeItem(at: scriptFile)

            var output = result.stdout
            if !result.stderr.isEmpty {
                output += (output.isEmpty ? "" : "\n") + "STDERR: \(result.stderr)"
            }
            if !result.succeeded {
                output += "\nExit code: \(result.exitCode)"
            }
            return AgentToolResult(content: output.isEmpty ? "(no output)" : output, isError: !result.succeeded, metadata: [:])
        } catch {
            try? FileManager.default.removeItem(at: scriptFile)
            return .error("Script execution failed: \(error.localizedDescription)")
        }
    }
}
```

### ShellEnvironmentTool (identifier: "shell_environment", .read tier)

```swift
struct ShellEnvironmentTool: AgentTool {
    let identifier = "shell_environment"
    let toolDescription = "Show current shell environment variables like PATH, HOME, and SHELL."
    let category = ToolCategory.shell
    let actionTier = ActionTier.read
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "filter": ToolProperty(type: "string", description: "Optional filter — only show variables containing this text"),
        ],
        required: []
    )

    private let shellService: ShellService
    init(service: ShellService) { self.shellService = service }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        let env = await shellService.environment()
        let filter = (parameters["filter"] as? String)?.lowercased()

        // Redact secrets
        let sensitivePatterns = ["secret", "token", "password", "key", "credential"]
        let filtered = env.sorted(by: { $0.key < $1.key }).compactMap { key, value -> String? in
            if let f = filter, !key.lowercased().contains(f) && !value.lowercased().contains(f) {
                return nil
            }
            let isSensitive = sensitivePatterns.contains { key.lowercased().contains($0) }
            return "\(key)=\(isSensitive ? "[REDACTED]" : value)"
        }

        if filtered.isEmpty {
            return .success("No matching environment variables found.")
        }
        return .success(filtered.joined(separator: "\n"))
    }
}
```

### ShellHistoryTool (identifier: "shell_history", .read tier)

```swift
struct ShellHistoryTool: AgentTool {
    let identifier = "shell_history"
    let toolDescription = "Show recent commands the agent has run in this session."
    let category = ToolCategory.shell
    let actionTier = ActionTier.read
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "limit": ToolProperty(type: "integer", description: "Number of entries (default 20)"),
        ],
        required: []
    )

    private let shellService: ShellService
    init(service: ShellService) { self.shellService = service }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        let limit = parameters["limit"] as? Int ?? 20
        let history = await shellService.recentHistory(limit: limit)

        if history.isEmpty {
            return .success("No commands have been run yet this session.")
        }

        let lines = history.map { entry in
            let status = entry.exitCode == 0 ? "OK" : "EXIT \(entry.exitCode)"
            let dur = String(format: "%.1fs", entry.duration)
            return "[\(status)] (\(dur)) \(entry.command)"
        }
        return .success(lines.joined(separator: "\n"))
    }
}
```

### EnvCheckPathTool (identifier: "env_check_path", .read tier)

```swift
struct EnvCheckPathTool: AgentTool {
    let identifier = "env_check_path"
    let toolDescription = "Check if a command or program is installed and available on your PATH."
    let category = ToolCategory.shell
    let actionTier = ActionTier.read
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "command": ToolProperty(type: "string", description: "The command to check for (e.g., 'python3', 'brew', 'git')"),
        ],
        required: ["command"]
    )

    private let shellService: ShellService
    init(service: ShellService) { self.shellService = service }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        guard let command = parameters["command"] as? String else {
            return .error("Missing required 'command' parameter")
        }

        if let path = await shellService.which(command) {
            return .success("\(command) is installed at: \(path.path)")
        } else {
            return .success("\(command) is not installed or not on your PATH.")
        }
    }
}
```

### SetupHomebrewTool (identifier: "setup_homebrew", .write tier)

```swift
struct SetupHomebrewTool: AgentTool {
    let identifier = "setup_homebrew"
    let toolDescription = "Check if Homebrew is installed, and install it if needed. Homebrew is a package manager that makes it easy to install software on your Mac."
    let category = ToolCategory.shell
    let actionTier = ActionTier.write
    let parameterSchema = ToolInputSchema(type: "object", properties: [:], required: [])

    private let shellService: ShellService
    init(service: ShellService) { self.shellService = service }

    func confirmationDescription(parameters: [String: Any]) -> String {
        "I'd like to check if Homebrew is installed, and install it if it isn't. Homebrew is a free, safe tool that helps install software on your Mac."
    }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        // Check if already installed
        if let brewPath = await shellService.which("brew") {
            let version = try await shellService.run(executable: brewPath.path, arguments: ["--version"])
            return .success("Homebrew is already installed.\n\(version.stdout.trimmingCharacters(in: .whitespacesAndNewlines))")
        }

        // Not installed — run the official installer
        let result = try await shellService.runCommand(
            "/bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"",
            timeout: 600
        )

        if result.succeeded {
            return .success("Homebrew has been installed successfully!")
        } else {
            return .error("Homebrew installation failed:\n\(result.stderr)")
        }
    }
}
```

### SetupDeveloperToolsTool (identifier: "setup_developer_tools", .write tier)

```swift
struct SetupDeveloperToolsTool: AgentTool {
    let identifier = "setup_developer_tools"
    let toolDescription = "Check if Xcode Command Line Tools are installed, and install them if needed. These are required for development tools like git."
    let category = ToolCategory.shell
    let actionTier = ActionTier.write
    let parameterSchema = ToolInputSchema(type: "object", properties: [:], required: [])

    private let shellService: ShellService
    init(service: ShellService) { self.shellService = service }

    func confirmationDescription(parameters: [String: Any]) -> String {
        "I'd like to check if Xcode Command Line Tools are installed, and install them if they aren't."
    }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        // Check if installed
        let check = try await shellService.runCommand("xcode-select -p 2>/dev/null")
        if check.succeeded {
            let path = check.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            return .success("Xcode Command Line Tools are installed at: \(path)")
        }

        // Not installed — trigger install
        let install = try await shellService.runCommand("xcode-select --install 2>&1", timeout: 10)
        return .success("Xcode Command Line Tools installation has been started. A system dialog should appear — follow the prompts to complete installation.")
    }
}
```

### Update ShellProvider

```swift
// Shellmate/Services/Tools/Shell/ShellProvider.swift
struct ShellProvider: ToolProvider {
    let category = ToolCategory.shell
    let displayName = "Shell & Terminal"
    private let shellService: ShellService

    init(shellService: ShellService) { self.shellService = shellService }

    var tools: [AgentTool] {
        [
            ShellExecuteTool(service: shellService),
            ShellScriptTool(service: shellService),
            ShellEnvironmentTool(service: shellService),
            ShellHistoryTool(service: shellService),
            EnvCheckPathTool(service: shellService),
            SetupHomebrewTool(service: shellService),
            SetupDeveloperToolsTool(service: shellService),
        ]
    }
}
```

### Tests

```swift
// ShellmateTests/Tools/Shell/ShellEnhancedToolTests.swift

// ShellScriptTool: runs simple echo script, returns output
// ShellScriptTool: requires script parameter
// ShellScriptTool: is write tier
// ShellEnvironmentTool: returns PATH and HOME
// ShellEnvironmentTool: redacts sensitive vars (set a SECRET env var, verify redacted)
// ShellEnvironmentTool: filter works
// ShellHistoryTool: returns history after running commands
// EnvCheckPathTool: finds echo
// EnvCheckPathTool: reports missing for nonexistent
// EnvCheckPathTool: requires command param
// SetupHomebrewTool: reports installed status (don't actually install)
// SetupDeveloperToolsTool: reports installed status
// ShellProvider: has 7 tools
```

- [ ] **Step 1: Write tests**
- [ ] **Step 2: Implement all 6 tools**
- [ ] **Step 3: Update ShellProvider**
- [ ] **Step 4: Run tests, verify**
- [ ] **Step 5: Commit**

```bash
git add Shellmate/Services/Tools/Shell/ ShellmateTests/Tools/Shell/
git commit -m "feat: add 6 enhanced shell tools — script, environment, history, path check, homebrew, dev tools"
```

---

## Task 2: Enhanced File Tools (9 tools)

**Files:**
- Create: `Shellmate/Services/Tools/Files/FilesSearchTool.swift`
- Create: `Shellmate/Services/Tools/Files/FilesMoveTool.swift`
- Create: `Shellmate/Services/Tools/Files/FilesCopyTool.swift`
- Create: `Shellmate/Services/Tools/Files/FilesDeleteTool.swift`
- Create: `Shellmate/Services/Tools/Files/FilesCompressTool.swift`
- Create: `Shellmate/Services/Tools/Files/FilesDecompressTool.swift`
- Create: `Shellmate/Services/Tools/Files/FilesDiskUsageTool.swift`
- Create: `Shellmate/Services/Tools/Files/FilesOpenTool.swift`
- Create: `Shellmate/Services/Tools/Files/FilesRevealInFinderTool.swift`
- Modify: `Shellmate/Services/Tools/Files/FilesProvider.swift`
- Test: `ShellmateTests/Tools/Files/FilesEnhancedToolTests.swift`

### FilesSearchTool (identifier: "files_search", .read tier)

Uses `mdfind` (Spotlight) via ShellService for system-wide search.

```swift
struct FilesSearchTool: AgentTool {
    let identifier = "files_search"
    let toolDescription = "Search for files on this Mac by name, content, or type using Spotlight."
    let category = ToolCategory.files
    let actionTier = ActionTier.read
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "query": ToolProperty(type: "string", description: "Search query — file name, content text, or Spotlight query"),
            "directory": ToolProperty(type: "string", description: "Optional: limit search to this directory"),
            "limit": ToolProperty(type: "integer", description: "Maximum results (default 20)"),
        ],
        required: ["query"]
    )

    private let shellService: ShellService
    init(shellService: ShellService) { self.shellService = shellService }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        guard let query = parameters["query"] as? String else {
            return .error("Missing required 'query' parameter")
        }
        let limit = parameters["limit"] as? Int ?? 20

        var args = ["mdfind"]
        if let dir = parameters["directory"] as? String {
            args += ["-onlyin", dir]
        }
        args += ["-name", query]

        let result = try await shellService.run(executable: "/usr/bin/mdfind", arguments: {
            var a: [String] = []
            if let dir = parameters["directory"] as? String { a += ["-onlyin", dir] }
            a += ["-name", query]
            return a
        }())

        if result.succeeded {
            let lines = result.stdout.components(separatedBy: "\n").filter { !$0.isEmpty }
            let limited = Array(lines.prefix(limit))
            if limited.isEmpty {
                return .success("No files found matching '\(query)'.")
            }
            return .success("Found \(lines.count) file(s):\n" + limited.joined(separator: "\n"))
        }
        return .error("Search failed: \(result.stderr)")
    }
}
```

### FilesMoveTool (identifier: "files_move", .write tier)

```swift
struct FilesMoveTool: AgentTool {
    let identifier = "files_move"
    let toolDescription = "Move or rename a file or folder."
    let category = ToolCategory.files
    let actionTier = ActionTier.write
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "source": ToolProperty(type: "string", description: "Path of file/folder to move"),
            "destination": ToolProperty(type: "string", description: "New path or directory to move into"),
        ],
        required: ["source", "destination"]
    )

    func confirmationDescription(parameters: [String: Any]) -> String {
        let src = parameters["source"] as? String ?? "?"
        let dst = parameters["destination"] as? String ?? "?"
        return "I'd like to move \(src) to \(dst)."
    }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        guard let source = parameters["source"] as? String else { return .error("Missing 'source'") }
        guard let destination = parameters["destination"] as? String else { return .error("Missing 'destination'") }

        if SecurityPolicy.isPathBlocked(source) || SecurityPolicy.isPathBlocked(destination) {
            return .error("Access denied: path is restricted")
        }

        let srcURL = URL(fileURLWithPath: source)
        let dstURL = URL(fileURLWithPath: destination)

        guard FileManager.default.fileExists(atPath: srcURL.path) else {
            return .error("Source not found: \(source)")
        }

        do {
            // If destination is an existing directory, move into it
            var isDir: ObjCBool = false
            let finalDst: URL
            if FileManager.default.fileExists(atPath: dstURL.path, isDirectory: &isDir), isDir.boolValue {
                finalDst = dstURL.appendingPathComponent(srcURL.lastPathComponent)
            } else {
                finalDst = dstURL
            }

            try FileManager.default.moveItem(at: srcURL, to: finalDst)
            return .success("Moved \(source) → \(finalDst.path)")
        } catch {
            return .error("Move failed: \(error.localizedDescription)")
        }
    }
}
```

### FilesCopyTool (identifier: "files_copy", .write tier)

Same pattern as move but uses `copyItem`.

### FilesDeleteTool (identifier: "files_delete", .destructive tier)

**CRITICAL: defaults to Trash, never permanent delete.**

```swift
struct FilesDeleteTool: AgentTool {
    let identifier = "files_delete"
    let toolDescription = "Move a file or folder to the Trash. This is safe — you can recover it from the Trash later."
    let category = ToolCategory.files
    let actionTier = ActionTier.destructive
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "path": ToolProperty(type: "string", description: "Path of file/folder to delete"),
        ],
        required: ["path"]
    )

    func confirmationDescription(parameters: [String: Any]) -> String {
        let path = parameters["path"] as? String ?? "?"
        return "This will move \(path) to the Trash."
    }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        guard let path = parameters["path"] as? String else { return .error("Missing 'path'") }

        if SecurityPolicy.isPathBlocked(path) {
            return .error("Access denied: path is restricted")
        }

        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: url.path) else {
            return .error("File not found: \(path)")
        }

        do {
            // Always use Trash — never permanent delete
            try FileManager.default.trashItem(at: url, resultingItemURL: nil)
            return .success("Moved to Trash: \(path)")
        } catch {
            return .error("Delete failed: \(error.localizedDescription)")
        }
    }
}
```

### FilesCompressTool (identifier: "files_compress", .write tier)

Uses `ditto -c -k` or `zip` via ShellService for structured args.

### FilesDecompressTool (identifier: "files_decompress", .write tier)

Uses `ditto -x -k` or `unzip` via ShellService.

### FilesDiskUsageTool (identifier: "files_disk_usage", .read tier)

Uses `du -hd N path` via ShellService with structured args.

### FilesOpenTool (identifier: "files_open", .write tier)

Uses `NSWorkspace.shared.open(url)` to open with default app.

### FilesRevealInFinderTool (identifier: "files_reveal_in_finder", .read tier)

Uses `NSWorkspace.shared.activateFileViewerSelecting([url])`.

### Update FilesProvider

```swift
struct FilesProvider: ToolProvider {
    let category = ToolCategory.files
    let displayName = "Files & Storage"
    private let shellService: ShellService

    init(shellService: ShellService = ShellService()) { self.shellService = shellService }

    var tools: [AgentTool] {
        [
            FileReadTool(), FileWriteTool(), FileListTool(),
            FilesSearchTool(shellService: shellService),
            FilesMoveTool(), FilesCopyTool(),
            FilesDeleteTool(),
            FilesCompressTool(shellService: shellService),
            FilesDecompressTool(shellService: shellService),
            FilesDiskUsageTool(shellService: shellService),
            FilesOpenTool(), FilesRevealInFinderTool(),
        ]
    }
}
```

**IMPORTANT**: `FilesProvider` currently has no `ShellService` dependency. It needs one now for search, compress, decompress, and disk usage. Add `shellService` parameter to init with a default value so existing callers (`ChatView`) don't break.

### Tests

```swift
// FilesSearchTool: searches tmp dir, finds created file
// FilesSearchTool: requires query
// FilesMoveTool: moves file in temp dir
// FilesMoveTool: blocks restricted paths
// FilesCopyTool: copies file in temp dir
// FilesDeleteTool: moves to trash (create temp file, delete, verify gone)
// FilesDeleteTool: is .destructive tier
// FilesDeleteTool: blocks restricted paths
// FilesCompressTool: creates zip from temp files
// FilesDecompressTool: extracts zip to temp dir
// FilesDiskUsageTool: returns usage for temp dir
// FilesOpenTool: conforms to AgentTool
// FilesRevealInFinderTool: conforms to AgentTool
// FilesProvider: has 12 tools
```

- [ ] **Step 1: Write tests**
- [ ] **Step 2: Implement all 9 tools**
- [ ] **Step 3: Update FilesProvider with ShellService dependency**
- [ ] **Step 4: Run tests, verify**
- [ ] **Step 5: Commit**

```bash
git add Shellmate/Services/Tools/Files/ ShellmateTests/Tools/Files/
git commit -m "feat: add 9 enhanced file tools — search, move, copy, delete (trash), compress, open, Finder"
```

---

## Task 3: Update ChatView + Final Verification

**Files:**
- Modify: `Shellmate/Views/Chat/ChatView.swift`

The `FilesProvider` now needs `ShellService`. Update the registration:

- [ ] **Step 1: Update FilesProvider registration**

In ChatView `sendMessage()`, change:
```swift
await registry.register(FilesProvider())
```
to:
```swift
await registry.register(FilesProvider(shellService: shellService))
```

- [ ] **Step 2: Run full test suite**

Run: `swift test 2>&1 | tail -5`
Expected: All tests pass

- [ ] **Step 3: Release build**

Run: `swift build -c release 2>&1 | tail -5`
Expected: Build succeeds

- [ ] **Step 4: Commit**

```bash
git add Shellmate/Views/Chat/ChatView.swift
git commit -m "feat: pass ShellService to FilesProvider for enhanced file tools"
```

- [ ] **Step 5: Tag**

```bash
git tag phase3-enhanced-shell-files-complete
```
