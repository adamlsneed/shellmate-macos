# Phase 6: Notes, Email, Automation, Media, TTS, Windows — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add AppleScriptService and 7 providers (Notes, Email, Automation, Media, TTS, Windows) with ~38 tools — completing the full agent capability suite.

**Architecture:** AppleScriptService is the shared service for Notes, Email, and Music tools. MediaProvider uses ScreenCaptureKit, CoreImage, Vision, and PDFKit. WindowProvider uses Accessibility API (AXUIElement). TTSProvider uses AVFoundation.

**Tech Stack:** Swift 6.0, macOS 14+, AVFoundation, Vision, PDFKit, CoreImage, AppKit, Swift Testing

**Baseline:** Phase 5 complete

---

## Task 1: AppleScriptService

**Files:**
- Create: `Shellmate/Services/Shared/AppleScriptService.swift`
- Test: `ShellmateTests/Tools/Shared/AppleScriptServiceTests.swift`

Shared actor for executing AppleScript safely:

```swift
actor AppleScriptService {
    func execute(script: String, timeout: TimeInterval = 30) async throws -> String
    func execute(app: String, command: String) async throws -> String
}
```

**CRITICAL:** Sanitize all string interpolation to prevent AppleScript injection. Escape quotes, backslashes. Use `NSAppleScript` or `osascript` via ShellService.

Tests: execute simple script, sanitization blocks injection attempts.

Commit: `feat: add AppleScriptService with injection-safe script execution`

---

## Task 2: NotesProvider — 5 tools

All via AppleScriptService targeting Notes.app.

| Tool | Identifier | Tier |
|---|---|---|
| NotesCreateTool | notes_create | .write |
| NotesSearchTool | notes_search | .read |
| NotesReadTool | notes_read | .read |
| NotesAppendTool | notes_append | .write |
| NotesListFoldersTool | notes_list_folders | .read |

Requires `.appleEvents` permission. Add `NSAppleEventsUsageDescription` to Info.plist.

Commit: `feat: add NotesProvider with 5 Notes.app tools via AppleScript`

---

## Task 3: EmailProvider — 4 tools

| Tool | Identifier | Tier |
|---|---|---|
| EmailSearchTool | email_search | .read | Spotlight `mdfind` with `kMDItemContentType == "com.apple.mail.emlx"` |
| EmailReadTool | email_read | .read | AppleScript to Mail.app |
| EmailComposeTool | email_compose | .write | **Opens compose window — NEVER auto-send** |
| EmailSummarizeUnreadTool | email_summarize_unread | .read | AppleScript to get unread count/subjects |

**CRITICAL:** EmailComposeTool opens a compose window in Mail.app. It NEVER sends automatically. The user must click Send themselves.

Commit: `feat: add EmailProvider with 4 Mail.app tools (never auto-sends)`

---

## Task 4: AutomationProvider — 7 tools

| Tool | Identifier | Tier | Approach |
|---|---|---|---|
| ShortcutsListTool | shortcuts_list | .read | `shortcuts list` CLI |
| ShortcutsRunTool | shortcuts_run | .write | `shortcuts run "{name}"` |
| CronListTool | cron_list | .read | `crontab -l` |
| CronAddTool | cron_add | .write | Append to crontab |
| CronRemoveTool | cron_remove | .destructive | Edit crontab |
| LaunchdListTool | launchd_list | .read | `launchctl list` + parse LaunchAgents |
| LaunchdCreateTool | launchd_create | .write | Write plist to ~/Library/LaunchAgents |

**SECURITY:** LaunchdCreateTool writes to LaunchAgents — this is already on the SecurityPolicy blocklist for file writes. Need to add an exception for this specific tool or route through a different path. Safest: write to a temp file, show content for approval, then move to LaunchAgents.

Commit: `feat: add AutomationProvider with Shortcuts, cron, and launchd tools`

---

## Task 5: MediaProvider — 10 tools

### Music tools (3) — via AppleScriptService
| Tool | Identifier | Tier |
|---|---|---|
| MusicSearchTool | music_search | .read |
| MusicPlayTool | music_play | .write |
| MusicQueueTool | music_queue | .read |

### Screenshot (1) — via `screencapture` CLI
| Tool | Identifier | Tier |
|---|---|---|
| ScreenshotCaptureTool | screenshot_capture | .write |

Params: area (full/window/selection), save_path, format (png/jpg), delay.

### Image tools (3) — via CoreImage/sips
| Tool | Identifier | Tier |
|---|---|---|
| ImageResizeTool | image_resize | .write |
| ImageConvertTool | image_convert | .write |
| ImageOCRTool | image_ocr | .read |

ImageOCRTool uses Vision framework `VNRecognizeTextRequest`.

### PDF tools (3) — via PDFKit
| Tool | Identifier | Tier |
|---|---|---|
| PDFReadTool | pdf_read | .read |
| PDFMergeTool | pdf_merge | .write |
| PDFSplitTool | pdf_split | .write |

Commit: `feat: add MediaProvider with music, screenshot, image, and PDF tools`

---

## Task 6: TTSProvider — 2 tools

| Tool | Identifier | Tier |
|---|---|---|
| TTSSpeakTool | tts_speak | .write |
| TTSVoicesTool | tts_voices | .read |

Uses `AVSpeechSynthesizer` (AVFoundation). TTSSpeakTool params: `text`, `voice` (opt), `rate` (opt).

Commit: `feat: add TTSProvider with text-to-speech and voice listing tools`

---

## Task 7: WindowProvider — 5 tools

| Tool | Identifier | Tier |
|---|---|---|
| WindowListTool | window_list | .read |
| WindowMoveTool | window_move | .write |
| WindowResizeTool | window_resize | .write |
| WindowArrangeTool | window_arrange | .write |
| WindowFocusTool | window_focus | .write |

Uses Accessibility API (`AXUIElement`). Requires `.accessibility` permission.

WindowArrangeTool supports presets: left_half, right_half, top_half, bottom_half, maximize, center.

Commit: `feat: add WindowProvider with 5 window management tools via Accessibility API`

---

## Task 8: Register All + Final Verification

- Register NotesProvider, EmailProvider, AutomationProvider, MediaProvider, TTSProvider, WindowProvider
- Add Info.plist entries: NSAppleEventsUsageDescription, NSScreenCaptureUsageDescription, NSMicrophoneUsageDescription
- Run full test suite
- Release build
- Tag `phase6-complete`

---

## Info.plist additions for Phase 6

```xml
<key>NSAppleEventsUsageDescription</key>
<string>Shellmate needs automation access to interact with Notes, Mail, Music, and other apps on your behalf.</string>
<key>NSScreenCaptureUsageDescription</key>
<string>Shellmate needs screen capture access to take screenshots when you ask.</string>
<key>NSMicrophoneUsageDescription</key>
<string>Shellmate needs microphone access for voice dictation and speech recognition.</string>
```
