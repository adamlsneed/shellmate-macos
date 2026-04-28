# Shellmate (macOS Native)

A native macOS AI agent that acts as a personal Mac assistant. Shellmate can manage your calendar, control system settings, read/write files, run terminal commands, search the web, manage apps, control audio/display, work with git/Docker/SSH, and much more — all through a conversational chat interface.

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 16+ / Swift 6.0+
- An API key from Anthropic (Claude) or OpenAI (GPT)

## Install

Download the latest DMG from [Releases](https://github.com/adamlsneed/shellmate-macos/releases), open it, and drag Shellmate to Applications. The app is signed and notarized — Gatekeeper will trust it.

## Build from Source

```bash
swift build            # Debug build
swift test             # Run all tests (625 tests)
swift build -c release # Release build
open Package.swift     # Open in Xcode
```

## Agent Capabilities (120+ Tools)

| Category | Tools | Examples |
|---|---|---|
| **Shell & Terminal** | 7 | Run commands, execute scripts, check PATH, install Homebrew |
| **Files & Storage** | 12 | Read, write, search, move, copy, delete (Trash), compress, open in Finder |
| **Web & Search** | 4 | Web search, fetch pages, download files, discover apps |
| **System Info** | 4 | Hardware info, CPU/memory/battery monitor, disk usage, network info |
| **Clipboard** | 3 | Read, write, clear clipboard |
| **Display** | 3 | Display info, brightness, dark mode toggle |
| **Audio & Volume** | 4 | Volume control, device listing, now playing, playback control |
| **Calendar** | 5 | List events, create, modify, delete, check availability |
| **Reminders** | 6 | Create, list, complete, modify, delete, list reminder lists |
| **Contacts** | 4 | Search, get details, create, update contacts |
| **Applications** | 12 | Search, install, update, uninstall (Homebrew), process list, kill, launch, quit |
| **Developer** | 17 | Git (full workflow), SSH, Docker, port management, environment variables |
| **Network** | 9 | Status, Wi-Fi scan/connect, Bluetooth, DNS, ping, port check, VPN |
| **Notes** | 5 | Create, search, read, append, list folders (via Notes.app) |
| **Email** | 4 | Search, read, compose (never auto-sends), summarize unread |
| **Automation** | 7 | Shortcuts, cron jobs, launch agents |
| **Media** | 10 | Music control, screenshots, image resize/convert/OCR, PDF read/merge/split |
| **Text-to-Speech** | 2 | Speak text, list voices |
| **Windows** | 5 | List, move, resize, arrange, focus windows |

## Project Structure

```
Shellmate/
  ShellmateApp.swift          -- @main entry point
  ContentView.swift           -- Root view routing
  Models/                     -- Data types (ChatMessage, ToolDefinition, Config)
  State/                      -- @Observable state (AppState, ChatState, AIConfigState)
  Services/
    AI/                       -- Anthropic/OpenAI clients, streaming, tool-use loop
    Tools/
      Core/                   -- AgentTool protocol, ToolProvider, ToolRegistry, CategoryResolver
      Shell/                  -- ShellService actor, 7 shell tools
      Files/                  -- 12 file management tools
      Web/                    -- 4 web tools
      System/                 -- 4 system info tools
      Clipboard/              -- 3 clipboard tools
      Display/                -- 3 display tools
      Audio/                  -- 4 audio tools
      Calendar/               -- CalendarService + 5 EventKit tools
      Reminders/              -- RemindersService + 6 EventKit tools
      Contacts/               -- ContactsService + 4 Contacts framework tools
      Apps/                   -- 7 Homebrew tools
      Process/                -- 5 process management tools
      Developer/              -- 17 git/SSH/Docker/port/env tools
      Network/                -- 9 network tools
      Notes/                  -- 5 AppleScript tools
      Email/                  -- 4 Mail.app tools
      Automation/             -- 7 Shortcuts/cron/launchd tools
      Media/                  -- 10 music/screenshot/image/PDF tools
      TTS/                    -- 2 text-to-speech tools
      Windows/                -- 5 Accessibility API tools
    Shared/                   -- ConfirmationService, PermissionManager, NaturalDateParser, AppleScriptService
    Platform/                 -- AppKit bridges (Sparkle, window management)
  Views/
    Chat/                     -- Chat interface with streaming + confirmation cards
    Wizard/                   -- First-time setup wizard
    Settings/                 -- Capabilities settings with permission dashboard
  Utilities/                  -- Keychain, colors, markdown, network monitor
  Resources/                  -- Assets, entitlements

ShellmateTests/               -- 605 tests across 195 suites
```

## Architecture

- **Tool System:** Protocol-based (`AgentTool` + `ToolProvider`) with `ToolRegistry` actor for routing and category-based schema filtering
- **Safety:** 3-tier confirmation (read/write/destructive), SecurityPolicy blocklists, protected process list, Trash-only deletes
- **Permissions:** Just-in-time macOS permission requests with friendly pre-prompt messages for non-technical users
- **Streaming:** Real-time response streaming via SSE with incremental text display
- **Concurrency:** Swift 6 strict concurrency — actors for ShellService, ToolRegistry, services
- **Dependencies:** Sparkle 2.9.0 (auto-update with EdDSA signing), SwiftSoup 2.13.2 (HTML extraction)

## Configuration

App data in `~/.shellmate/`:
- `shellmate.json` — configuration (enabled tools, auto-approve, API settings)
- `workspace/` — agent identity files (SOUL.md, AGENTS.md, etc.)

## CI/CD

Automated via GitHub Actions on tag push (`v*`):
- Build → Code sign → Assemble .app → DMG → Notarize → Staple → Sparkle appcast → GitHub Release

## Version

Current: 0.0.4 (build 2)

## License

MIT
