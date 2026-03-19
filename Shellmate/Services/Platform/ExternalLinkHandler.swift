import AppKit
import os

// BRIDGE: NSWorkspace.shared.open(url) — SwiftUI has no native open-in-browser API

/// Opens URLs in the system default browser.
enum ExternalLinkHandler {
    private static let logger = Logger(subsystem: "com.shellmate.app", category: "links")

    /// Open a URL string in the system default browser.
    /// Returns true if the URL was valid and the open request was sent.
    @discardableResult
    static func open(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else {
            logger.warning("Invalid URL string: \(urlString)")
            return false
        }
        return open(url)
    }

    /// Open a URL in the system default browser.
    /// Returns true if the open request was sent.
    @discardableResult
    static func open(_ url: URL) -> Bool {
        guard url.scheme == "http" || url.scheme == "https" || url.scheme == "mailto" else {
            logger.warning("Refusing to open URL with unsupported scheme: \(url.scheme ?? "nil")")
            return false
        }
        NSWorkspace.shared.open(url)
        logger.info("Opened external URL: \(url.absoluteString)")
        return true
    }
}
