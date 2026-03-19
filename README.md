# Shellmate (macOS Native)

A native macOS AI helper app built with Swift and SwiftUI. Shellmate acts as a personal Mac assistant that can execute shell commands, read/write files, and search the web -- all through a conversational chat interface.

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 16+ / Swift 6.0+
- An API key from Anthropic (Claude) or OpenAI (GPT)

## Build & Run

```bash
# Build
swift build

# Run tests
swift test

# Open in Xcode
open Package.swift
```

## Project Structure

```
Shellmate/
  ShellmateApp.swift     -- @main entry point, window, menu commands
  ContentView.swift      -- Root view routing (loading/preflight/wizard/chat)
  Models/                -- Codable structs and enums (AgentSpec, ChatMessage, etc.)
  State/                 -- @Observable state classes (AppState, ChatState, etc.)
  Services/
    AI/                  -- Anthropic/OpenAI clients, router, tool-use loop
    Tools/               -- Tool execution engine (shell, files, web)
    Platform/            -- AppKit bridges (Sparkle, window management, lifecycle)
    ConfigService.swift  -- Read/write/backup ~/.shellmate/shellmate.json
    GeneratorService.swift -- Workspace file generators (SOUL.md, etc.)
  Views/
    Wizard/              -- First-time setup wizard phases
    Chat/                -- Main chat interface with tool call display
    Setup/               -- Preflight check, AI key setup
    Settings/            -- macOS Settings scene
    Components/          -- Reusable UI components
  Utilities/             -- Keychain, colors, markdown rendering, network monitor
  Resources/             -- Assets, entitlements, Info.plist
ShellmateTests/          -- 165 tests across 32 suites
```

## Architecture

- **UI:** SwiftUI with `@Observable` state management (macOS 14+)
- **Networking:** URLSession with async/await for AI API calls and web tools
- **Concurrency:** Structured concurrency throughout; `ToolExecutor` is an actor
- **Dependencies:** Sparkle 2 (auto-update), SwiftSoup (HTML text extraction)
- **Security:** API keys in Keychain only; SecurityPolicy enforces path/URL blocklists

## Configuration

App data is stored in `~/.shellmate/`:
- `shellmate.json` -- main configuration file
- `workspace/` -- generated agent identity files (SOUL.md, AGENTS.md, etc.)

## Version

Current: 0.0.1

Stay below 1.0.0 until the product generates revenue.

## License

MIT
