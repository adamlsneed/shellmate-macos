# Refactor Baseline

Metrics captured before, during, and after the agent capabilities refactor.

## Pre-Refactor (2026-03-19)

| Metric | Value |
|---|---|
| **Tests** | 165 in 32 suites |
| **Source files** | 55 Swift files |
| **Source lines** | 4,057 |
| **Tools** | 6 (static enums) |
| **Dependencies** | 2 (Sparkle, SwiftSoup) |
| **Baseline commit** | c4f7b07 (main) |

## Post-Security-Audit (refactor branch)

| Metric | Before | After |
|---|---|---|
| **Tests** | 165 | 182 (+17) |
| **Source lines** | 4,057 | 4,485 (+428) |

## Post-Agent-Capabilities (current)

| Metric | Before | After | Delta |
|---|---|---|---|
| **Tests** | 165 in 32 suites | 605 in 195 suites | +440 tests, +163 suites |
| **Source files** | 55 | 208 | +153 |
| **Source lines** | 4,057 | ~14,200 | +10,100 |
| **Test files** | 25 | 53 | +28 |
| **Test lines** | — | ~6,400 | — |
| **Tools** | 6 (static enums) | 120+ (AgentTool protocol) | +114 |
| **Providers** | 0 | 19 | +19 |
| **Shared services** | 0 | 6 | +6 |
| **Dependencies** | 2 | 2 | No change |

## Phases Completed

| Phase | What | Tools Added |
|---|---|---|
| 1 — Foundation | Protocol architecture, ToolRegistry, ConfirmationService, PermissionManager, ShellService, NaturalDateParser | 6 (migrated) |
| 2 — System | System info, Clipboard, Display, Audio | +14 |
| 3 — Enhanced | Shell +6, Files +9 | +15 |
| 4 — Productivity | Calendar, Reminders, Contacts (EventKit + Contacts) | +15 |
| 5 — Power User | Apps, Process, Developer, Network | +40 |
| 6 — Automation | Notes, Email, Automation, Media, TTS, Windows | +38 |
