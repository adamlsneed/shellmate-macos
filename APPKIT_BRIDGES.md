# AppKit Bridges

Log of every AppKit usage with reason and future SwiftUI replacement path.

| Location | What | Why | Future SwiftUI Path |
|---|---|---|---|
| `ShellmateApp.swift` | `SPUStandardUpdaterController` (Sparkle) | Sparkle requires AppKit integration for update UI | When SwiftUI gets native update framework support |
| `ShellmateApp.swift` | `CheckForUpdatesViewModel` uses `NSKeyValueObservation` | Sparkle's `SPUUpdater` exposes KVO, not Combine/Observation | Sparkle may adopt @Observable in future versions |

<!-- Add new entries here as bridges are created -->
