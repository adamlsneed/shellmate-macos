# Conventions

## File Naming
- Swift files use PascalCase matching their primary type: `ConfigService.swift`, `ChatView.swift`
- One primary type per file (small related types like CodingKeys enums may be in the same file)
- Test files: `<Type>Tests.swift` (e.g., `ConfigServiceTests.swift`)

## Directory Organization
```
Shellmate/
  Models/        — Codable structs, enums, protocols for data shapes
  State/         — @Observable classes for UI state management
  Services/      — Business logic, IO, networking (no UI imports)
    AI/          — Anthropic/OpenAI clients, router, tool-use loop
    Tools/       — Tool execution engine (shell, files, web)
  Views/         — SwiftUI views organized by feature area
    Wizard/      — First-time setup wizard phases
    Chat/        — Main chat interface
    Setup/       — Preflight, AI setup
    Settings/    — macOS Settings scene
    Components/  — Reusable UI components
  Utilities/     — Pure helpers (Keychain, colors, markdown)
  Resources/     — Assets, entitlements, Info.plist
```

## SwiftUI View Composition
- Extract subviews when a view body exceeds ~50 lines
- Use `private var` computed properties for sub-sections within the same file
- Use separate `struct` for reusable components in `Components/`
- Every view should have a Preview provider

## State Management
- Use `@Observable` (Observation framework) for all state containers
- Pass state via `.environment()` for app-wide state (AppState, AIConfigState)
- Pass state via init parameters for local/scoped state
- Never use `@Published` / `ObservableObject` — use `@Observable` exclusively

## Error Handling
- Use typed error enums conforming to `LocalizedError`
- Service methods `throw` on failure — let callers decide how to surface
- Views catch errors and display via state properties (e.g., `error: String?`)

## AppKit Bridging
- Only use AppKit when SwiftUI cannot achieve the required behavior
- Mark every bridge with `// BRIDGE: <reason>` inline comment
- Log all bridges in `APPKIT_BRIDGES.md`
- Wrap in `NSViewRepresentable` / `NSViewControllerRepresentable`

## Logging
- Use `os.Logger` with subsystem `"com.shellmate.app"`
- Category per service: `"anthropic"`, `"openai"`, `"tools"`, `"shell"`, `"migration"`, etc.
- Log levels: `.info` for routine, `.warning` for recoverable issues, `.error` for failures

## Concurrency
- All async work uses structured concurrency (`async/await`, `TaskGroup`)
- `ToolExecutor` is an `actor` to prevent concurrent shell conflicts
- `@MainActor` on all `@Observable` state classes and SwiftUI view models
- No GCD (`DispatchQueue`) or OperationQueue

## Security
- API keys stored in Keychain only — never UserDefaults or plain files
- `SecurityPolicy` enforces path and URL blocklists for all tool operations
- No force unwraps (`!`) outside of tests
