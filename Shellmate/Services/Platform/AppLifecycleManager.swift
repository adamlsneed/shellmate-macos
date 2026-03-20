import AppKit
import os

// BRIDGE: NSApplicationDelegate via NSObject — SwiftUI's onOpenURL/onChange don't cover
// all app lifecycle events (dock click, reopen, termination with cleanup)

/// Handles macOS app lifecycle events: activation, dock click, termination.
/// @unchecked Sendable: NSApplicationDelegate methods are always called on the main thread by AppKit.
/// This class has no mutable state, so Sendable conformance is safe.
final class AppLifecycleManager: NSObject, NSApplicationDelegate, @unchecked Sendable {
    private static let logger = Logger(subsystem: "com.shellmate.app", category: "lifecycle")

    /// Called when the user clicks the dock icon while the app is running.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            // No visible windows — bring to front or create one
            WindowManager.activateMainWindow()
            Self.logger.info("Dock icon clicked with no visible windows — activating")
        }
        return true
    }

    /// Called when the app is about to terminate.
    func applicationWillTerminate(_ notification: Notification) {
        Self.logger.info("App terminating — performing cleanup")
        // Post a notification so the ToolExecutor and other services can cancel running work
        NotificationCenter.default.post(name: .shellmateWillTerminate, object: nil)
    }

    /// Called when the app becomes active (e.g., user switches to it).
    func applicationDidBecomeActive(_ notification: Notification) {
        Self.logger.info("App became active")
    }
}

extension Notification.Name {
    /// Posted when the app is about to terminate, allowing services to clean up.
    static let shellmateWillTerminate = Notification.Name("shellmateWillTerminate")
}
