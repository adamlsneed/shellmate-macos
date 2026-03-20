# Known Issues

Tracked issues, TODOs, and technical debt.

## Open

- [ ] ConfigFileWatcher uses GCD DispatchSource — acceptable since the API requires it
- [ ] `AnthropicClient` and `OpenAIClient` base URLs use force-unwrapped `URL(string:)!` — acceptable for compile-time-constant URLs
- [ ] ConfigFileWatcher uses GCD DispatchSource (NWPathMonitor also requires a DispatchQueue) — acceptable since the APIs require it
- [ ] `AnthropicClient` and `OpenAIClient` base URLs use force-unwrapped `URL(string:)!` — acceptable for compile-time-constant URLs

## Implemented

- [x] App icon — terminal turtle with shell prompt (1024px, all 10 sizes)
- [x] Streaming chat display — ToolUseLoop uses router.stream() for real-time text
- [x] Confirmation UI — ConfirmationCardView renders inline with Approve/Deny
- [x] Capability settings persist to shellmate.json via ConfigService
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
- [x] ~~TEST_COVERAGE.md stale~~ — updated to 605 tests
