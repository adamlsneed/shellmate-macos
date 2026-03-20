# Known Issues

Tracked issues, TODOs, and technical debt.

## Open

- [ ] App icon assets not yet created (circuit-board turtle) — placeholder AppIcon in asset catalog
- [ ] Sparkle EdDSA public key not yet generated (`SUPublicEDKey` in Info.plist is empty) — **RELEASE BLOCKER** (see SECURITY_AUDIT.md C-001). Auto-update checks disabled as interim mitigation.
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

## Security — Deferred Findings

These are from the security audit (SECURITY_AUDIT.md). Risk accepted or scheduled for later.

- [ ] App sandbox disabled (C-003) — intentional, required for shell execution and arbitrary file access. Compensating controls: SecurityPolicy path/URL blocklist, shell command blocklist.
- [ ] WebFetchTool allows HTTP (M-004) — HTTPS-only would break legitimate use cases. Low risk: content is displayed in-app, not executed.
- [ ] Brave Search API key in env var only (M-006) — matches Brave's documented setup pattern. Low priority.
- [ ] No certificate pinning for API endpoints (M-007) — adds operational complexity with pin rotation. Default TLS validation is sufficient for desktop app threat model.
- [ ] OAuth token refresh flow not implemented (M-008) — full OAuth flow deferred.
- [ ] Clipboard copy without sensitive content timeout (L-002) — low priority hardening.
- [ ] No input length limits on chat text (L-007) — API providers have their own token limits.
- [ ] API key held as Swift String in memory (L-001) — impractical to fully mitigate in Swift.
- [ ] Keychain items accessible to same-user processes (L-005) — consequence of disabled sandbox.

## Technical Debt

- [x] ~~ConfigService duplicate computed properties~~ — removed `configFilePath`, kept `configDirectory`/`workspacePath` as aliases
- [x] ~~Date formatting duplication~~ — extracted shared `BackupTimestamp` utility
- [ ] TEST_COVERAGE.md total count is stale (says 103, actual is now 182)
