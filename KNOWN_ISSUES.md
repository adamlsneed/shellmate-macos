# Known Issues

Tracked issues, TODOs, and technical debt.

## Open

- [ ] App icon assets not yet created (circuit-board turtle) — placeholder AppIcon in asset catalog
- [ ] Sparkle EdDSA public key not yet generated (`SUPublicEDKey` in Info.plist is empty)
- [ ] No CI pipeline yet (GitHub Actions for archive + DMG + notarize + release)
- [ ] ConfigFileWatcher uses GCD DispatchSource (NWPathMonitor also requires a DispatchQueue) — these are acceptable since the APIs require it, but noted for CONVENTIONS.md deviation
- [ ] `AnthropicClient` and `OpenAIClient` base URLs use force-unwrapped `URL(string:)!` — acceptable for compile-time-constant URLs but noted per conventions

## Implemented (previously tracked as open)

- [x] Chat streaming wired to UI via ToolUseLoop with full tool-call display
- [x] Wizard phases fully implemented (conversation, review, generate, capabilities, done)
- [x] Simple setup flow implemented (SimpleSetup, SimpleAISetup, SimpleCapabilities)
- [x] Chat history persistence (save/restore/delete)
- [x] Wizard progress persistence (save/restore)

## Deferred

- [ ] OAuth token acquisition flow (detection works via `sk-ant-oat` prefix, but no UI for obtaining tokens)
- [ ] Home Assistant integration
- [ ] Google Places integration
- [ ] LanceDB memory mode
- [ ] Streaming chat display (currently uses non-streaming ToolUseLoop; streaming parsers are implemented and tested but not yet wired to ChatView)

## Technical Debt

- [ ] ConfigService `configDir`/`configFile`/`workspaceDir` are stored alongside `configDirectory`/`configFilePath`/`workspacePath` computed properties — one set should be removed
- [ ] Date formatting for backup filenames is duplicated between ConfigService and WorkspaceService
- [ ] TEST_COVERAGE.md total count is stale (says 103, actual is 165)

<!-- Add new issues here -->
