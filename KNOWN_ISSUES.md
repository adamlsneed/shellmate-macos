# Known Issues

Tracked issues, TODOs, and technical debt.

## Open

- [ ] App icon assets not yet created (circuit-board turtle) — placeholder AppIcon in asset catalog
- [ ] Streaming chat display not wired — streaming parsers are implemented and tested but ChatView uses non-streaming ToolUseLoop. Users see blank screen then full response.
- [ ] ConfirmationService auto-approves everything — ConfirmationUIHandler placeholder always returns true. ConfirmationCardView exists but is not rendered in ChatView.
- [ ] CapabilitiesConfig `enabledCategories` and `autoApproveCategories` not persisted — settings toggles are local state only, not saved to shellmate.json.
- [ ] ConfigFileWatcher uses GCD DispatchSource (NWPathMonitor also requires a DispatchQueue) — acceptable since the APIs require it
- [ ] `AnthropicClient` and `OpenAIClient` base URLs use force-unwrapped `URL(string:)!` — acceptable for compile-time-constant URLs

## Implemented

- [x] Sparkle EdDSA public key generated and set in Info.plist (C-001 resolved)
- [x] CI/CD pipeline — GitHub Actions: build, sign, notarize, DMG, appcast, release
- [x] Full agent capabilities: 120+ tools across 19 providers (Phases 1-6)
- [x] 605 tests passing, release build clean
- [x] v0.0.1 shipped and notarized
- [x] Chat streaming wired to UI via ToolUseLoop with full tool-call display
- [x] Wizard phases fully implemented
- [x] Simple setup flow implemented
- [x] Chat/wizard history persistence

## Deferred

- [ ] OAuth token acquisition flow (detection works via `sk-ant-oat` prefix, but no UI)
- [ ] Home Assistant integration
- [ ] Google Places integration
- [ ] LanceDB memory mode

## Security — Deferred Findings

- [ ] App sandbox disabled (C-003) — intentional, compensated by SecurityPolicy blocklists
- [ ] WebFetchTool allows HTTP (M-004) — low risk
- [ ] Brave Search API key in env var only (M-006)
- [ ] No certificate pinning (M-007)
- [ ] OAuth token refresh not implemented (M-008)
- [ ] Clipboard timeout (L-002), input length limits (L-007), String keys in memory (L-001), keychain scope (L-005)

## Technical Debt

- [x] ~~ConfigService duplicate properties~~ — resolved
- [x] ~~Date formatting duplication~~ — resolved
- [ ] TEST_COVERAGE.md total count is stale (says 103, actual is 605)
