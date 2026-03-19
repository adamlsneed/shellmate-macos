# Shellmate — Swift Rewrite Blueprint

> Generated from exhaustive analysis of the Electron codebase (55 source files, 72 total project files).
> Target: native macOS app using Swift 6.0+, macOS 14+ (Sonoma) minimum deployment.

---

## 1. Application Profile

**Shellmate** is a self-contained macOS desktop app that acts as a personal AI helper. On first launch, a conversational wizard personalizes an AI agent (name, personality, mission, Mac apps it knows, safety rules). The wizard generates workspace configuration files at `~/.shellmate/`. After setup, the app becomes a full-screen chat interface where the user converses with their personalized AI agent, which can execute shell commands, read/write files, search the web, and fetch web pages — all built-in, no external binaries.

**Target platform:** macOS only (no iOS/Catalyst — this app uses shell execution, file system access, and Mac-specific integrations).

**Critical features:**
- First-time setup wizard with AI-led personalization conversation
- Workspace file generation (SOUL.md, IDENTITY.md, TOOLS.md, etc.)
- Full-screen streaming chat with tool execution (shell, files, web)
- Inline tool call/result display with friendly descriptions
- Auto-update via GitHub Releases
- Code signing + notarization
- Light/dark theme support
- Two setup paths: detailed (technical) and simple (non-technical)

**Nice-to-haves (currently implemented but lower priority):**
- Legacy `~/.openclaw/` migration
- OAuth token support (alongside API key auth)
- Home Assistant integration
- Google Places integration
- LanceDB memory mode

---

## 2. Swift Architecture Decision Record

### 2.1 UI Framework: **SwiftUI**

**Rationale:** Shellmate's UI is relatively straightforward — wizard flow, chat interface, settings panel. No complex custom drawing or AppKit-only features are needed. SwiftUI provides:
- Declarative UI matching React's component model (familiar mental model from the existing codebase)
- Built-in dark mode support (replaces Tailwind's `dark:` variant system)
- Native macOS controls (menus, sheets, popovers)
- `NavigationStack` for wizard phase flow
- `ScrollViewReader` for chat auto-scroll
- macOS 14+ has mature SwiftUI with `@Observable` macro

**Risk:** The streaming chat with inline tool displays is the most complex view. SwiftUI's `List` / `LazyVStack` should handle this, but may need performance tuning for long conversations.

### 2.2 Data Layer: **Direct File I/O + Codable**

**Rationale:** Shellmate stores configuration in a single JSON file (`~/.shellmate/shellmate.json`) and generated markdown files. There is no database, no relational data, no queries. The existing `readConfig()` / `writeConfig()` / `backupConfig()` pattern maps directly to:
- `Codable` structs for `ShellmateConfig` (replaces `shellmate.json` read/write)
- `FileManager` for directory creation, file existence checks, workspace management
- `JSONEncoder` / `JSONDecoder` with `.prettyPrinted` output
- String templates for markdown generation (replaces `server/generators/*.js`)

No ORM or database framework needed.

### 2.3 Networking: **URLSession + async/await**

**Rationale:** Shellmate makes exactly two types of outbound HTTP calls:
1. **AI API calls** (Anthropic `v1/messages`, OpenAI `v1/chat/completions`) — streaming responses with tool use loops
2. **Web tools** (Brave Search API, arbitrary URL fetch)

`URLSession` handles both natively. The streaming AI responses use `URLSession.AsyncBytes` (replaces the SSE `text/event-stream` parsing). No need for Alamofire — the API surface is small and well-defined.

**Key mapping:**
| Electron Pattern | Swift Equivalent |
|---|---|
| `fetch()` with JSON body | `URLSession.shared.data(for: request)` |
| SSE `EventSource` parsing | `URLSession.shared.bytes(for: request)` + line parsing |
| `AbortController` (15s timeout) | `URLRequest.timeoutInterval` + `Task.cancel()` |

### 2.4 State Management: **@Observable (Observation framework)**

**Rationale:** The two Zustand stores (`teamSpec.js`, `aiConfig.js`) map cleanly to `@Observable` classes:
- `WizardState` — phase, conversation messages, agent spec, generation results
- `AIConfig` — provider, API key, model, configured flag
- `ThemeManager` — light/dark mode (though macOS handles this natively via `NSApp.effectiveAppearance`)

`@Observable` (macOS 14+) provides automatic view updates without `@Published` boilerplate. The stores are small enough that TCA would be overkill.

**Persistence:** `AIConfig` persists to Keychain (API keys) + UserDefaults (provider/model selection). `WizardState` persists generated files to `~/.shellmate/`.

### 2.5 IPC Replacement: **None needed — direct function calls**

**Rationale:** The Electron app has **zero IPC channels**. All main↔renderer communication goes through an embedded Express HTTP server with token auth. In the Swift rewrite, this entire HTTP layer disappears:
- Express routes become Swift service methods called directly by views
- No serialization boundary — Swift structs passed directly
- The auth token mechanism is unnecessary (no separate processes)
- SSE streaming becomes `AsyncSequence` yielded from service methods

This is the single biggest simplification in the rewrite.

### 2.6 Background Work: **Swift Concurrency (structured concurrency + actors)**

**Rationale:** Shellmate's background work consists of:
1. AI API calls with streaming responses (long-running)
2. Tool execution (shell commands up to 60s, file I/O, web fetches up to 15s)
3. Workspace file generation (CPU-bound string templating, fast)
4. Auto-update checks (periodic network call)

All map to `async/await` with `Task` groups:
- **AI streaming:** `Task` with `for await line in ...` loop (cancellable)
- **Tool execution:** `Process` for shell commands, `FileManager` for file I/O — all `async`
- **Tool-use loop:** Sequential `async` function (max 15 rounds, matching existing loop)
- **Actor isolation:** `ToolExecutor` actor prevents concurrent shell command conflicts

No GCD or OperationQueue needed.

---

## 3. Dependency Mapping Table

### Production Dependencies

| Electron/Node Dependency | Purpose | Swift Equivalent | Notes |
|---|---|---|---|
| `express@4.18` | HTTP server for API routes | **Remove entirely** | Views call services directly; no HTTP layer needed |
| `electron-updater@6.8` | GitHub Releases auto-update | **Sparkle 2** (SPM: `sparkle-project/Sparkle`) | Industry standard for macOS auto-update. Supports EdDSA signing, delta updates, GitHub Releases as feed source |
| `open@9.1` | Open URLs in system browser | `NSWorkspace.shared.open(url)` | One-liner, no dependency needed |

### Dev/Build Dependencies

| Electron/Node Dependency | Purpose | Swift Equivalent | Notes |
|---|---|---|---|
| `electron@33.4` | Desktop app shell (Chromium) | **Native macOS app** | Entire reason for rewrite — eliminates 150MB+ runtime |
| `electron-builder@25.1` | DMG packaging, code signing | **Xcode archive + `xcodebuild`** | Built into Xcode; `create-dmg` or `dmgbuild` for DMG creation in CI |
| `react@18.3` | UI component framework | **SwiftUI** | Declarative paradigm maps well |
| `react-dom@18.3` | DOM rendering | **SwiftUI** (renders natively) | No DOM equivalent needed |
| `vite@5.4` | Bundler + dev server + HMR | **Xcode build system** | No separate bundler; Xcode handles compilation |
| `@vitejs/plugin-react@4.7` | React Fast Refresh | **Xcode Previews** | SwiftUI previews provide similar live feedback |
| `tailwindcss@3.4` | Utility CSS framework | **SwiftUI modifiers + custom `ShellmateTheme`** | Define color palette as `Color` extensions; use `.font()`, `.padding()`, `.background()` modifiers |
| `postcss@8.5` | CSS processing | **Remove** | No CSS in Swift |
| `autoprefixer@10.4` | CSS vendor prefixes | **Remove** | No CSS in Swift |
| `zustand@4.5` | State management | **`@Observable` classes** | Direct mapping; simpler API |

### Implicit Node.js Dependencies (no package, but used)

| Node.js API / Pattern | Purpose | Swift Equivalent | Notes |
|---|---|---|---|
| `child_process.execFile` | Shell command execution (`shell_exec` tool) | `Process` (Foundation) | Set `/bin/zsh` as executable, pipe stdout/stderr, enforce timeout via `Task.sleep` + `process.terminate()` |
| `fs.readFile` / `fs.writeFile` | File I/O tools | `FileManager` + `String(contentsOf:)` / `data.write(to:)` | Direct mapping |
| `fs.readdir` (recursive) | `file_list` tool | `FileManager.enumerator(at:)` with depth limit | Use `resourceKeys` for type detection |
| `crypto.randomBytes(32)` | Auth token generation | **Remove** | No inter-process auth needed |
| `http.get` / `fetch` | Web fetch tool + AI API calls | `URLSession` | Handle redirects, timeouts, response size limits |
| `node:path` / `node:url` | Path manipulation | `URL` / `FileManager` | Foundation provides equivalent APIs |
| HTML text extraction (regex-based) | `web_fetch` strips HTML tags | `NSAttributedString(html:)` or **SwiftSoup** (SPM) | SwiftSoup is cleaner for HTML→text; `NSAttributedString` works but is AppKit-dependent |

---

## 4. Feature-by-Feature Migration Checklist

### Setup & Configuration

- [ ] **Preflight check** (`PreflightCheck.jsx` → `server/routes/preflight.js`)
  - Swift: Check `~/.shellmate/shellmate.json` exists via `FileManager.default.fileExists(atPath:)`. Show onboarding if missing.
  - Risk: **Low** — trivial file existence check
  - Effort: **S**

- [ ] **Legacy migration** (`~/.openclaw/` → `~/.shellmate/`)
  - Swift: `FileManager.default.copyItem(at:to:)` for config + workspace directory. Update workspace paths in JSON.
  - Risk: **Low** — straightforward file copy
  - Effort: **S**

- [ ] **Config read/write/backup** (`server/utils/config.js`)
  - Swift: `Codable` struct `ShellmateConfig` with `JSONDecoder`/`JSONEncoder`. Backup via timestamped copy before write.
  - Risk: **Low** — well-defined JSON schema
  - Effort: **S**

- [ ] **AI provider setup** (`AISetup.jsx`, `SimpleAISetup.jsx`)
  - Swift: SwiftUI form with `SecureField` for API key, `Picker` for provider/model. Store key in Keychain via `Security` framework.
  - Risk: **Low** — standard form UI
  - Effort: **M**

### Wizard Flow

- [ ] **Conversational personalization** (`ConversationPhase.jsx` → `POST /api/chat`)
  - Swift: `async` function calling Anthropic/OpenAI API. Parse `<shellmate-spec>` XML blocks from response. Update `WizardState` incrementally.
  - Risk: **Medium** — XML block parsing from AI responses requires careful regex/parsing
  - Effort: **M**

- [ ] **Agent spec review/edit** (`ReviewStep.jsx`)
  - Swift: SwiftUI form with `TextField` for name/personality/mission, `List` with swipe-to-delete for `never` rules, `ForEach` for use cases.
  - Risk: **Low** — standard form editing
  - Effort: **M**

- [ ] **File generation** (`server/generators/*.js` → `POST /api/generate`)
  - Swift: Pure functions `generateSOUL(agent:) → String`, `generateIDENTITY(agent:) → String`, etc. String interpolation templates.
  - Risk: **Low** — pure string templating (8 generators, each <50 lines)
  - Effort: **M**

- [ ] **File writing + conflict detection** (`server/routes/files.js`)
  - Swift: `FileManager` to check existence, create directories, write files. Backup existing files with timestamp suffix.
  - Risk: **Low** — basic file I/O with safety checks
  - Effort: **S**

- [ ] **Capabilities configuration** (`CapabilitiesStep.jsx`, `SimpleCapabilities.jsx`)
  - Swift: SwiftUI toggles for web search, shell access, file write, memory. Write deny list to config JSON.
  - Risk: **Low** — toggle UI + config write
  - Effort: **M**

- [ ] **Validation** (`server/routes/validate.js`)
  - Swift: Check config file, workspace, API key presence, web search key. Return pass/fail for each check.
  - Risk: **Low** — 4 boolean checks
  - Effort: **S**

- [ ] **Simple setup flow** (`SimpleSetup.jsx`)
  - Swift: Alternate `NavigationStack` path with fewer steps. Auto-fill defaults via `populateSimpleDefaults()`.
  - Risk: **Low** — subset of full wizard
  - Effort: **M**

- [ ] **Two-path wizard selection** (full vs simple)
  - Swift: Initial screen with two `BigButton` options routing to different `NavigationStack` destinations.
  - Risk: **Low**
  - Effort: **S**

### Chat Interface

- [ ] **Streaming chat with SSE** (`ChatApp.jsx` + `useSSEChat.js` → `POST /api/agent-chat/:agentId`)
  - Swift: `URLSession.AsyncBytes` to stream Anthropic/OpenAI responses. Parse JSON lines. Update `@Observable` chat state. Display with `ScrollView` + `LazyVStack`.
  - Risk: **Medium** — streaming parsing + live UI updates need careful async handling
  - Effort: **L**

- [ ] **Tool-use loop** (`server/tools/loop.js`)
  - Swift: `async` function with max 15 iterations. Call AI API → check for tool_use stop reason → execute tools → append results → repeat.
  - Risk: **Medium** — must handle both Anthropic and OpenAI response formats correctly
  - Effort: **L**

- [ ] **Message rendering** (`MessageBubble.jsx`)
  - Swift: SwiftUI `View` with conditional styling for user vs assistant messages. Markdown rendering via `Text` with `AttributedString` (macOS 14+ supports markdown).
  - Risk: **Low** — standard chat bubble UI
  - Effort: **M**

- [ ] **Tool call display** (`ToolCallDisplay.jsx`, `FriendlyToolStatus.jsx`)
  - Swift: Expandable `DisclosureGroup` showing tool name (friendly), input, result. Collapse by default, expand on tap.
  - Risk: **Low** — straightforward disclosure UI
  - Effort: **M**

- [ ] **Quick actions** (`QuickActions.jsx`)
  - Swift: `LazyVGrid` of suggestion buttons shown when chat is empty. Each inserts a pre-written prompt.
  - Risk: **Low**
  - Effort: **S**

- [ ] **Chat auto-scroll** (`useChatUI.js`)
  - Swift: `ScrollViewReader` with `.scrollTo(id:anchor:)` on new message. Detect user scroll-up to pause auto-scroll.
  - Risk: **Low** — well-documented SwiftUI pattern
  - Effort: **S**

### Tool Execution Engine

- [ ] **Shell command execution** (`shell_exec` in `executor.js`)
  - Swift: `Process()` with `/bin/zsh -c "command"`. Pipe `standardOutput` + `standardError`. Enforce timeout via `Task.sleep` + `process.terminate()`. Truncate output at 100k chars. Max buffer 10MB.
  - Risk: **Medium** — timeout handling and process cleanup must be robust
  - Effort: **M**

- [ ] **File read** (`file_read` in `executor.js`)
  - Swift: `String(contentsOf: url, encoding: .utf8)` with 2MB size limit check via `FileManager.attributesOfItem`. Block sensitive paths.
  - Risk: **Low**
  - Effort: **S**

- [ ] **File write** (`file_write` in `executor.js`)
  - Swift: `data.write(to: url, atomically: true)`. Create parent dirs with `FileManager.createDirectory(at:withIntermediateDirectories:true)`. Block sensitive paths.
  - Risk: **Low**
  - Effort: **S**

- [ ] **File list** (`file_list` in `executor.js`)
  - Swift: `FileManager.enumerator(at:includingPropertiesForKeys:)` with depth tracking. Return relative paths. Block sensitive paths.
  - Risk: **Low**
  - Effort: **S**

- [ ] **Web search** (`web_search` in `executor.js`)
  - Swift: `URLSession` GET to `https://api.search.brave.com/res/v1/web/search` with API key header. Parse JSON response for title/URL/description.
  - Risk: **Low** — single API call
  - Effort: **S**

- [ ] **Web fetch** (`web_fetch` in `executor.js`)
  - Swift: `URLSession` GET with 15s timeout. Strip HTML → extract text. Block private IPs (10.x, 172.16-31.x, 192.168.x, 169.254.x) and localhost. Truncate at 50k chars.
  - Risk: **Medium** — HTML→text extraction, IP validation
  - Effort: **M**

- [ ] **Path security** (`isPathBlocked` in `executor.js`)
  - Swift: Check resolved path against blocklist (`~/.ssh`, `~/.gnupg`, `~/.aws`, `/etc/`, `/System/`, etc.). Use `URL.standardized` to resolve symlinks.
  - Risk: **Low** — direct port of string matching
  - Effort: **S**

- [ ] **URL security** (`isUrlBlocked` in `executor.js`)
  - Swift: Parse URL host, check against private IP ranges and localhost variants. Only allow `http`/`https` schemes.
  - Risk: **Low**
  - Effort: **S**

- [ ] **Tool deny map** (`definitions.js` deny categories)
  - Swift: Enum `ToolDenyCategory` with cases `.exec`, `.write`, `.read`, `.web`, `.browser`. Map to tool names. Filter available tools per agent config.
  - Risk: **Low**
  - Effort: **S**

### AI Provider Integration

- [ ] **Anthropic API client** (`callAnthropicRaw` in `ai-clients.js`)
  - Swift: `URLSession` POST to `https://api.anthropic.com/v1/messages`. Headers: `X-API-Key` or `Authorization: Bearer` (OAuth). Body: model, messages, system, tools, max_tokens. Parse streaming response.
  - Risk: **Medium** — streaming JSON parsing for tool_use blocks
  - Effort: **L**

- [ ] **OpenAI API client** (`callOpenAIRaw` in `ai-clients.js`)
  - Swift: `URLSession` POST to `https://api.openai.com/v1/chat/completions`. Headers: `Authorization: Bearer`. Body: model, messages (system in array), tools (function format), max_tokens. Parse streaming response.
  - Risk: **Medium** — different response format from Anthropic
  - Effort: **L**

- [ ] **Provider detection/normalization** (`detectProvider`, `normalizeModel` in `ai-clients.js`)
  - Swift: Pattern match on model name prefix (`claude` → `.anthropic`, `gpt`/`o1`/`o3` → `.openai`). Strip provider prefix from model string.
  - Risk: **Low**
  - Effort: **S**

- [ ] **API key resolution** (`resolveApiKey` in `ai-clients.js`)
  - Swift: Check Keychain first, then `ProcessInfo.processInfo.environment` for `ANTHROPIC_API_KEY` / `OPENAI_API_KEY` / `CLAUDE_CODE_OAUTH_TOKEN`.
  - Risk: **Low**
  - Effort: **S**

- [ ] **OAuth token support** (detects `sk-ant-oat*` prefix)
  - Swift: Check key prefix, set appropriate auth header (`Bearer` + beta header for OAuth vs `X-API-Key` for standard).
  - Risk: **Low**
  - Effort: **S**

### Platform Integration

- [ ] **Auto-update** (`electron-updater` + `checkForUpdates()`)
  - Swift: **Sparkle 2** framework. Configure `SUUpdater` with GitHub Releases appcast. EdDSA key signing. Show update dialog.
  - Risk: **Medium** — Sparkle integration requires appcast XML generation in CI
  - Effort: **M**

- [ ] **Menu bar** (Electron `Menu.buildFromTemplate`)
  - Swift: SwiftUI `.commands` modifier with `CommandGroup` for About, Check Updates, standard Edit menu (undo/redo/cut/copy/paste). macOS provides these largely for free.
  - Risk: **Low** — standard macOS menu
  - Effort: **S**

- [ ] **External link handling** (`shell.openExternal()`)
  - Swift: `NSWorkspace.shared.open(url)` — one line
  - Risk: **Low**
  - Effort: **S**

- [ ] **Window configuration** (1200×800 BrowserWindow)
  - Swift: `.defaultSize(width: 1200, height: 800)` on `WindowGroup`. Set minimum size with `.frame(minWidth:minHeight:)`.
  - Risk: **Low**
  - Effort: **S**

- [ ] **Code signing + notarization** (`electron/notarize.js`, entitlements)
  - Swift: Xcode automatic signing. Notarization via `notarytool` in CI. Entitlements file for hardened runtime (only need `network.client` — no JIT/unsigned-memory needed without V8).
  - Risk: **Low** — simpler than Electron (no JIT entitlements needed)
  - Effort: **S**

- [ ] **Dark mode / theming** (`theme.js`, CSS `dark:` variants)
  - Swift: macOS native dark mode via `@Environment(\.colorScheme)`. Define `ShellmateColors` with `Color` adaptive assets. Toggle via `NSApp.appearance = NSAppearance(named: .darkAqua)`.
  - Risk: **Low** — macOS handles automatically
  - Effort: **S**

### Settings

- [ ] **Settings panel** (`SettingsPanel.jsx`)
  - Swift: SwiftUI `Settings` scene (opens via ⌘, automatically). Tabs for Theme, Connection, Advanced.
  - Risk: **Low** — standard macOS settings window
  - Effort: **M**

---

## 5. Recommended Project Structure

```
Shellmate/
├── Shellmate.xcodeproj
├── Package.swift                          # SPM dependencies (Sparkle, SwiftSoup)
│
├── Shellmate/
│   ├── ShellmateApp.swift                 # @main entry point, WindowGroup, commands
│   ├── ContentView.swift                  # Root view: loading → preflight → wizard → chat
│   │
│   ├── Models/
│   │   ├── AgentSpec.swift                # Codable struct: name, personality, mission, mac_apps, use_cases, never
│   │   ├── ShellmateConfig.swift          # Codable struct: full shellmate.json schema
│   │   ├── ChatMessage.swift              # Message model: role, content, toolCalls, toolResults
│   │   ├── ToolDefinition.swift           # Tool schema: name, description, parameters
│   │   └── AIProvider.swift               # Enum: .anthropic, .openai + model normalization
│   │
│   ├── State/
│   │   ├── WizardState.swift              # @Observable: phase, conversation, spec, generation results
│   │   ├── ChatState.swift                # @Observable: messages, isStreaming, currentToolCalls
│   │   ├── AIConfig.swift                 # @Observable: provider, model, configured + Keychain persistence
│   │   └── AppState.swift                 # @Observable: setupComplete, isLoading, currentView
│   │
│   ├── Services/
│   │   ├── ConfigService.swift            # Read/write/backup ~/.shellmate/shellmate.json
│   │   ├── WorkspaceService.swift         # Resolve agent workspace, check setup status
│   │   ├── GeneratorService.swift         # Generate SOUL.md, IDENTITY.md, TOOLS.md, etc.
│   │   ├── ValidationService.swift        # Run preflight + setup validation checks
│   │   ├── MigrationService.swift         # Legacy ~/.openclaw/ → ~/.shellmate/ migration
│   │   │
│   │   ├── AI/
│   │   │   ├── AnthropicClient.swift      # Anthropic v1/messages API (streaming + non-streaming)
│   │   │   ├── OpenAIClient.swift         # OpenAI v1/chat/completions API (streaming + non-streaming)
│   │   │   ├── AIRouter.swift             # Provider detection, key resolution, model normalization
│   │   │   └── ToolUseLoop.swift          # Agentic loop: call AI → execute tools → repeat (max 15)
│   │   │
│   │   └── Tools/
│   │       ├── ToolExecutor.swift         # Actor: routes tool name → implementation
│   │       ├── ShellTool.swift            # Process-based shell execution with timeout
│   │       ├── FileReadTool.swift         # File read with size limit + path security
│   │       ├── FileWriteTool.swift        # File write with path security
│   │       ├── FileListTool.swift         # Directory listing with depth limit
│   │       ├── WebSearchTool.swift        # Brave Search API client
│   │       ├── WebFetchTool.swift         # URL fetch + HTML→text + IP blocking
│   │       └── SecurityPolicy.swift       # Path blocklist, URL blocklist, IP range checks
│   │
│   ├── Views/
│   │   ├── Wizard/
│   │   │   ├── WizardContainer.swift      # NavigationStack with phase progress
│   │   │   ├── ConversationPhase.swift    # AI-led personalization chat (simple + full modes)
│   │   │   ├── ReviewStep.swift           # Editable agent spec form
│   │   │   ├── GenerateStep.swift         # File preview + write + conflict detection
│   │   │   ├── CapabilitiesStep.swift     # Full capabilities toggles
│   │   │   ├── SimpleCapabilities.swift   # Non-technical capabilities
│   │   │   ├── DoneStep.swift             # Validation + chat preview
│   │   │   └── SimpleSetup.swift          # Non-technical 4-step flow
│   │   │
│   │   ├── Chat/
│   │   │   ├── ChatView.swift             # Full-screen chat with input bar
│   │   │   ├── MessageBubble.swift        # User/assistant message display
│   │   │   ├── ToolCallDisplay.swift      # Expandable tool call + result
│   │   │   ├── FriendlyToolStatus.swift   # Human-readable tool descriptions
│   │   │   └── QuickActions.swift         # Empty-state suggestion grid
│   │   │
│   │   ├── Setup/
│   │   │   ├── AISetupView.swift          # Full provider/auth setup
│   │   │   ├── SimpleAISetup.swift        # Non-technical key entry
│   │   │   └── PreflightView.swift        # Config check + migration prompt
│   │   │
│   │   ├── Settings/
│   │   │   └── SettingsView.swift         # macOS Settings scene (⌘,)
│   │   │
│   │   └── Components/
│   │       ├── BigButton.swift            # Large accessible button
│   │       ├── ProgressIndicator.swift    # 5-phase wizard progress bar
│   │       ├── LoadingSpinner.swift       # Spinner + bouncing dots
│   │       ├── FileTreeView.swift         # Generated file tree preview
│   │       └── FormField.swift            # Reusable labeled input field
│   │
│   ├── Utilities/
│   │   ├── Keychain.swift                 # Security framework wrapper for API key storage
│   │   ├── ShellmateColors.swift          # Color palette: shell (cyan) + navy (dark) + adaptive
│   │   ├── MarkdownRenderer.swift         # AttributedString markdown helpers
│   │   └── HTMLTextExtractor.swift        # HTML → plain text (or SwiftSoup wrapper)
│   │
│   └── Resources/
│       ├── Assets.xcassets/               # App icon (circuit-board turtle), color sets
│       ├── Shellmate.entitlements         # com.apple.security.network.client only
│       └── Info.plist                     # App metadata, Sparkle config
│
├── ShellmateTests/
│   ├── GeneratorTests.swift               # Test markdown generation output
│   ├── SecurityPolicyTests.swift          # Test path/URL blocking
│   ├── ConfigServiceTests.swift           # Test JSON read/write/backup
│   ├── ToolExecutorTests.swift            # Test tool execution + deny map
│   └── AIRouterTests.swift                # Test provider detection, model normalization
│
└── ci/
    ├── build.sh                           # xcodebuild archive + export + notarize
    └── appcast.xml                        # Sparkle update feed (generated in CI)
```

### Swift Package Manager Dependencies

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0"),
    .package(url: "https://github.com/scinfu/SwiftSoup", from: "2.7.0"),  // HTML→text for web_fetch
]
```

Only **2 external dependencies** (vs 10 in the Electron version). Everything else is Foundation/SwiftUI.

---

## 6. Migration Order

### Phase 1: Foundation (get something running)
**Goal:** App launches, shows a window, reads/writes config.

| # | Task | Files | Depends On | Risk |
|---|---|---|---|---|
| 1.1 | Xcode project setup, SPM deps, app icon | Project structure, `Package.swift` | — | Low |
| 1.2 | `ShellmateConfig` Codable model | `Models/ShellmateConfig.swift` | — | Low |
| 1.3 | `ConfigService` (read/write/backup) | `Services/ConfigService.swift` | 1.2 | Low |
| 1.4 | `AppState` + root `ContentView` | `State/AppState.swift`, `ContentView.swift` | 1.3 | Low |
| 1.5 | `PreflightView` (config check, migration) | `Views/Setup/PreflightView.swift`, `Services/MigrationService.swift` | 1.3, 1.4 | Low |
| 1.6 | Color palette + theme | `Utilities/ShellmateColors.swift`, color assets | — | Low |

**Milestone:** App opens, detects setup state, shows loading → preflight check.

### Phase 2: AI Integration (core value)
**Goal:** Can call Anthropic/OpenAI APIs, parse responses, handle tool-use format.

| # | Task | Files | Depends On | Risk |
|---|---|---|---|---|
| 2.1 | `AIProvider` enum + `AIRouter` | `Models/AIProvider.swift`, `Services/AI/AIRouter.swift` | — | Low |
| 2.2 | `AnthropicClient` (non-streaming first) | `Services/AI/AnthropicClient.swift` | 2.1 | Med |
| 2.3 | `OpenAIClient` (non-streaming first) | `Services/AI/OpenAIClient.swift` | 2.1 | Med |
| 2.4 | `AIConfig` state + `Keychain` wrapper | `State/AIConfig.swift`, `Utilities/Keychain.swift` | 2.1 | Low |
| 2.5 | `AISetupView` (provider picker, key input) | `Views/Setup/AISetupView.swift` | 2.4 | Low |

**Milestone:** Can enter API key, call Claude/GPT, get a text response.

### Phase 3: Wizard Flow (setup experience)
**Goal:** Complete first-time setup from conversation through file generation.

| # | Task | Files | Depends On | Risk |
|---|---|---|---|---|
| 3.1 | `AgentSpec` model | `Models/AgentSpec.swift` | — | Low |
| 3.2 | `WizardState` + phase navigation | `State/WizardState.swift` | 3.1 | Low |
| 3.3 | `ConversationPhase` (AI chat + spec parsing) | `Views/Wizard/ConversationPhase.swift` | 2.2, 3.2 | Med |
| 3.4 | `ReviewStep` (editable spec form) | `Views/Wizard/ReviewStep.swift` | 3.2 | Low |
| 3.5 | `GeneratorService` (8 markdown generators) | `Services/GeneratorService.swift` | 3.1 | Low |
| 3.6 | `GenerateStep` (file preview + write) | `Views/Wizard/GenerateStep.swift` | 3.5 | Low |
| 3.7 | `CapabilitiesStep` + `DoneStep` | `Views/Wizard/CapabilitiesStep.swift`, `DoneStep.swift` | 3.2 | Low |
| 3.8 | `SimpleSetup` alternate flow | `Views/Wizard/SimpleSetup.swift` | 3.3-3.7 | Low |
| 3.9 | `ValidationService` | `Services/ValidationService.swift` | 1.3 | Low |

**Milestone:** Full wizard runs end-to-end, generates workspace files.

### Phase 4: Tool Execution (the power)
**Goal:** All 6 tools work with security policies.

| # | Task | Files | Depends On | Risk |
|---|---|---|---|---|
| 4.1 | `SecurityPolicy` (path + URL blocklists) | `Services/Tools/SecurityPolicy.swift` | — | Low |
| 4.2 | `ShellTool` (Process + timeout) | `Services/Tools/ShellTool.swift` | 4.1 | Med |
| 4.3 | `FileReadTool` + `FileWriteTool` + `FileListTool` | `Services/Tools/File*.swift` | 4.1 | Low |
| 4.4 | `WebSearchTool` (Brave API) | `Services/Tools/WebSearchTool.swift` | — | Low |
| 4.5 | `WebFetchTool` (URL fetch + HTML strip) | `Services/Tools/WebFetchTool.swift` | 4.1 | Med |
| 4.6 | `ToolExecutor` actor (routing + deny map) | `Services/Tools/ToolExecutor.swift` | 4.2-4.5 | Low |
| 4.7 | `ToolDefinition` model + provider format converters | `Models/ToolDefinition.swift` | — | Low |

**Milestone:** All tools execute correctly with security enforcement.

### Phase 5: Streaming Chat (the experience)
**Goal:** Full streaming chat with live tool execution display.

| # | Task | Files | Depends On | Risk |
|---|---|---|---|---|
| 5.1 | Streaming support in `AnthropicClient` | Update `AnthropicClient.swift` | 2.2, 4.7 | Med |
| 5.2 | Streaming support in `OpenAIClient` | Update `OpenAIClient.swift` | 2.3, 4.7 | Med |
| 5.3 | `ToolUseLoop` (agentic loop, max 15 rounds) | `Services/AI/ToolUseLoop.swift` | 5.1, 5.2, 4.6 | Med |
| 5.4 | `ChatState` + `ChatMessage` model | `State/ChatState.swift`, `Models/ChatMessage.swift` | 5.3 | Low |
| 5.5 | `ChatView` (messages + input bar) | `Views/Chat/ChatView.swift` | 5.4 | Med |
| 5.6 | `MessageBubble` + markdown rendering | `Views/Chat/MessageBubble.swift`, `Utilities/MarkdownRenderer.swift` | 5.5 | Low |
| 5.7 | `ToolCallDisplay` + `FriendlyToolStatus` | `Views/Chat/ToolCallDisplay.swift`, `FriendlyToolStatus.swift` | 5.5 | Low |
| 5.8 | `QuickActions` (empty state suggestions) | `Views/Chat/QuickActions.swift` | 5.5 | Low |

**Milestone:** Full streaming chat with tool calls displayed inline. **App is usable.**

### Phase 6: Polish & Distribution
**Goal:** Production-ready with auto-update and CI.

| # | Task | Files | Depends On | Risk |
|---|---|---|---|---|
| 6.1 | `SettingsView` (macOS Settings scene) | `Views/Settings/SettingsView.swift` | 1.6, 2.4 | Low |
| 6.2 | Menu bar commands (About, Check Updates) | `ShellmateApp.swift` commands | — | Low |
| 6.3 | Sparkle auto-update integration | `Package.swift`, `Info.plist`, `ShellmateApp.swift` | — | Med |
| 6.4 | Code signing + notarization + entitlements | `Shellmate.entitlements`, Xcode settings | — | Low |
| 6.5 | CI pipeline (GitHub Actions: archive + DMG + notarize + release) | `ci/build.sh`, `.github/workflows/release.yml` | 6.3, 6.4 | Med |
| 6.6 | App icon assets (circuit-board turtle) | `Assets.xcassets` | — | Low |
| 6.7 | Common UI components (`BigButton`, `ProgressIndicator`, etc.) | `Views/Components/*.swift` | — | Low |

**Milestone:** Signed, notarized DMG auto-published via GitHub Actions.

---

## 7. Risk Register

| Risk | Severity | Mitigation |
|---|---|---|
| **Streaming AI response parsing** — Anthropic and OpenAI have different streaming formats; tool_use blocks arrive incrementally | High | Build non-streaming first (Phase 2), add streaming in Phase 5. Test with real API responses. Consider Anthropic's Swift SDK if one exists by build time. |
| **Shell command timeout/cleanup** — `Process` termination on macOS can leave zombie processes | Medium | Use `process.terminate()` + `process.waitUntilExit()`. Set `qualityOfService` on Task. Test with long-running commands. |
| **HTML→text extraction quality** — `web_fetch` needs to strip HTML reliably | Medium | Use SwiftSoup for proper DOM parsing rather than regex (matching current Node.js regex approach but more robust). |
| **Chat performance with long conversations** — SwiftUI `LazyVStack` with many messages + tool displays | Medium | Use `id` on each message for efficient diffing. Consider `NSViewRepresentable` with `NSTableView` if SwiftUI perf is insufficient. |
| **Sparkle appcast generation in CI** — Need to generate/update appcast XML on each release | Low | Use `generate_appcast` tool from Sparkle. Store appcast in GitHub Pages or as release asset. |
| **Markdown rendering fidelity** — `AttributedString` markdown support may not cover all cases (code blocks, tables) | Low | For chat messages, basic markdown (bold, italic, code, links) is sufficient. Code blocks can use monospace font. Tables unlikely in AI responses. |

---

## 8. What Gets Eliminated

The Swift rewrite removes significant complexity that exists only because of Electron:

| Eliminated | Why |
|---|---|
| **Express server** (7 route files, `server/index.js`) | Views call services directly — no HTTP serialization layer |
| **Auth token system** (`crypto.randomBytes`, fetch interceptor, middleware) | Single-process app — no inter-process auth needed |
| **SSE streaming infrastructure** (`sse.js`, `EventSource` parsing) | `AsyncSequence` replaces SSE for streaming |
| **Vite build system** (`vite.config.js`, HMR, dev server) | Xcode handles compilation natively |
| **Tailwind + PostCSS pipeline** (3 config files) | SwiftUI modifiers + color assets |
| **React + Zustand** (component tree, store boilerplate) | SwiftUI + `@Observable` — less code for same result |
| **Chromium runtime** (~150MB) | Native binary (~5-10MB) |
| **Node.js runtime** (~40MB) | Foundation framework (included in macOS) |
| **ASAR packaging + unpacking** | No web assets to bundle |
| **JIT/unsigned-memory entitlements** | No V8 engine — simpler hardened runtime |
| **`node_modules/`** (hundreds of transitive deps) | 2 SPM dependencies |

**Estimated app size reduction:** ~200MB (Electron) → ~10-15MB (native Swift).

---

## 9. No Clean Swift Equivalent — Workarounds

| Feature | Issue | Workaround |
|---|---|---|
| **Brave Search API client** | No official Swift SDK | Direct `URLSession` call — API is simple REST (GET with query params + API key header). Trivial to implement. |
| **HTML text extraction** (regex-based in Node.js) | No built-in HTML→text in Swift | Use **SwiftSoup** (SPM package) — proper DOM parser, more reliable than the existing regex approach. Actually an improvement. |
| **OAuth token detection** (`sk-ant-oat*` prefix) | Anthropic OAuth is a specific convention | String prefix check — `apiKey.hasPrefix("sk-ant-oat")`. Identical logic, just Swift syntax. |
| **`<shellmate-spec>` XML parsing from AI responses** | AI returns spec blocks embedded in natural language | Use regex to extract blocks, then parse with `XMLParser` or simple string scanning. Same approach as current JS implementation. |
| **Fetch interceptor for auth headers** | JavaScript's `window.fetch` override pattern | Not needed — no HTTP layer between UI and services. Auth is only for external API calls (API key passed directly). |

---

*Generated: 2026-03-19 | Source: `/Users/adam/dev/shellmate` (commit `7e4633e`) | 55 source files analyzed*
