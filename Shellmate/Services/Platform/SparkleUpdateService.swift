import Foundation
import Sparkle
import os

// BRIDGE: SPUStandardUpdaterController + SPUUpdater — Sparkle requires AppKit integration

/// Wraps Sparkle's update controller for use with SwiftUI menu commands.
/// Uses KVO to observe updater state since Sparkle doesn't yet use @Observable.
@MainActor
final class SparkleUpdateService: NSObject, ObservableObject {
    private static let logger = Logger(subsystem: "com.shellmate.app", category: "updater")

    let updaterController: SPUStandardUpdaterController

    /// Whether the "Check for Updates" menu item should be enabled.
    @Published var canCheckForUpdates = false

    /// Whether an update check is currently in progress.
    @Published var isChecking = false

    private var observation: NSKeyValueObservation?

    override init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        super.init()

        // BRIDGE: NSKeyValueObservation — Sparkle exposes `canCheckForUpdates` via KVO
        observation = updaterController.updater.observe(
            \.canCheckForUpdates,
            options: [.initial, .new]
        ) { [weak self] updater, change in
            Task { @MainActor in
                self?.canCheckForUpdates = updater.canCheckForUpdates
            }
        }

        Self.logger.info("Sparkle update service initialized")
    }

    /// Trigger a manual update check (from menu item).
    func checkForUpdates() {
        guard canCheckForUpdates else {
            Self.logger.warning("Update check requested but updater is not ready")
            return
        }
        Self.logger.info("Checking for updates...")
        updaterController.checkForUpdates(nil)
    }

    /// Enable or disable automatic update checks.
    var automaticallyChecksForUpdates: Bool {
        get { updaterController.updater.automaticallyChecksForUpdates }
        set { updaterController.updater.automaticallyChecksForUpdates = newValue }
    }

    /// The interval between automatic update checks (in seconds).
    var updateCheckInterval: TimeInterval {
        get { updaterController.updater.updateCheckInterval }
        set { updaterController.updater.updateCheckInterval = newValue }
    }
}
