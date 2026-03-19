import AppKit
import os

// BRIDGE: NSWindow frame autosave — SwiftUI does not expose setFrameAutosaveName
// BRIDGE: NSApplication window management — SwiftUI WindowGroup doesn't provide direct window access

/// Manages window position/size persistence and single-window enforcement.
enum WindowManager {
    private static let logger = Logger(subsystem: "com.shellmate.app", category: "window")
    private static let autosaveName = "ShellmateMainWindow"

    /// Configure the main window for frame autosave after the window appears.
    /// Call this from `.onAppear` of the root view.
    @MainActor
    static func configureMainWindow() {
        guard let window = NSApplication.shared.windows.first else {
            logger.warning("No window found for frame autosave configuration")
            return
        }
        window.setFrameAutosaveName(autosaveName)
        logger.info("Window frame autosave configured with name: \(autosaveName)")
    }

    /// Bring the main window to front, or create one if none exists.
    /// Used for dock icon click and app activation handling.
    @MainActor
    static func activateMainWindow() {
        if let window = NSApplication.shared.windows.first {
            window.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
            logger.info("Main window activated")
        }
    }

    /// Returns true if the app currently has a visible main window.
    @MainActor
    static var hasVisibleWindow: Bool {
        NSApplication.shared.windows.contains { $0.isVisible }
    }
}
