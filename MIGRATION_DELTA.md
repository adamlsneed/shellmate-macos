# Migration Delta — Electron → Swift

Documents Electron features that were intentionally dropped, deferred, or reimagined.

## Eliminated (by design)

| Feature | Reason |
|---|---|
| Express HTTP server (7 route files) | Views call services directly — no IPC needed |
| Auth token system (crypto.randomBytes) | Single-process app — no inter-process auth |
| SSE streaming infrastructure | `AsyncSequence` replaces SSE |
| Vite build system + HMR | Xcode handles compilation natively |
| Tailwind + PostCSS pipeline | SwiftUI modifiers + ShellmateColors |
| React + Zustand | SwiftUI + @Observable |
| Chromium runtime (~150MB) | Native binary (~10-15MB) |
| Node.js runtime (~40MB) | Foundation framework (included in macOS) |
| ASAR packaging | No web assets to bundle |
| JIT/unsigned-memory entitlements | No V8 engine |

## Reimagined

| Electron Approach | Swift Approach |
|---|---|
| `electron-store` (JSON file) | `Codable` + `FileManager` (same JSON format, native parsing) |
| `electron-updater` | Sparkle 2 (industry standard for macOS) |
| HTML regex stripping | SwiftSoup DOM parser (actually better) |
| Zustand stores | `@Observable` classes (less boilerplate) |

## Deferred

| Feature | Status | Notes |
|---|---|---|
| Home Assistant integration | Not implemented | Low priority per plan |
| Google Places integration | Not implemented | Low priority per plan |
| LanceDB memory mode | Not implemented | Core memory only for now |
| OAuth token acquisition flow | Partial | Detection works, no UI for obtaining tokens |

<!-- Update as implementation progresses -->
