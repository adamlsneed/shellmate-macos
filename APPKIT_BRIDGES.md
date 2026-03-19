# AppKit Bridges

Log of every AppKit usage with reason and future SwiftUI replacement path.

| Location | What | Why | Future SwiftUI Path |
|---|---|---|---|
| `Services/Platform/SparkleUpdateService.swift` | `SPUStandardUpdaterController` (Sparkle) | Sparkle requires AppKit integration for update UI | When SwiftUI gets native update framework support |
| `Services/Platform/SparkleUpdateService.swift` | `NSKeyValueObservation` on `SPUUpdater.canCheckForUpdates` | Sparkle's `SPUUpdater` exposes KVO, not Combine/Observation | Sparkle may adopt @Observable in future versions |
| `Services/Platform/WindowManager.swift` | `NSWindow.setFrameAutosaveName` | SwiftUI `WindowGroup`/`Window` does not expose frame autosave | When SwiftUI adds window position persistence API |
| `Services/Platform/WindowManager.swift` | `NSApplication.shared.windows` | SwiftUI has no API to enumerate or access windows | When SwiftUI adds window management APIs |
| `Services/Platform/WindowManager.swift` | `NSApplication.shared.activate` | SwiftUI has no direct app activation API | When SwiftUI adds activation control |
| `Services/Platform/ExternalLinkHandler.swift` | `NSWorkspace.shared.open(url)` | SwiftUI has no native open-in-system-browser API | When SwiftUI adds `openURL` for external browser (not in-app) |
| `Services/Platform/AppLifecycleManager.swift` | `NSApplicationDelegate` (`applicationShouldHandleReopen`, `applicationWillTerminate`) | SwiftUI does not expose dock-click or pre-termination hooks | When SwiftUI adds full lifecycle callbacks |
| `ShellmateApp.swift` | `@NSApplicationDelegateAdaptor(AppLifecycleManager.self)` | Required to register the `NSApplicationDelegate` for lifecycle events | Same as above |

<!-- Add new entries here as bridges are created -->
