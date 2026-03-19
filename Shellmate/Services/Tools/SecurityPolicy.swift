import Foundation

/// Security policy for path and URL access.
enum SecurityPolicy {
    /// Blocked path prefixes — files/dirs the agent must never read or write.
    private static let blockedPaths: [String] = [
        ".ssh", ".gnupg", ".gpg", ".aws", ".azure",
        ".config/gcloud", ".kube",
        "Library/Keychains",
        ".env",
    ]

    private static let blockedAbsolutePaths: [String] = [
        "/etc", "/System", "/Library", "/private",
        "/usr/local/etc",
    ]

    /// Check if a file path should be blocked.
    static func isPathBlocked(_ path: String) -> Bool {
        // Resolve to absolute path
        let url = URL(fileURLWithPath: path).standardized
        let resolved = url.path

        // Check absolute path blocklist
        for blocked in blockedAbsolutePaths {
            if resolved.hasPrefix(blocked) { return true }
        }

        // Check home-relative blocklist
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if resolved.hasPrefix(home) {
            let relative = String(resolved.dropFirst(home.count + 1))
            for blocked in blockedPaths {
                if relative.hasPrefix(blocked) { return true }
            }
        }

        return false
    }

    /// Check if a URL should be blocked (private IPs, localhost, non-HTTP).
    static func isURLBlocked(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString),
              let scheme = url.scheme?.lowercased(),
              let host = url.host?.lowercased() else {
            return true // Block malformed URLs
        }

        // Only allow HTTP/HTTPS
        guard scheme == "http" || scheme == "https" else { return true }

        // Block localhost variants
        if host == "localhost" || host == "0.0.0.0" || host == "::1" || host == "[::1]" {
            return true
        }

        // Block private IP ranges
        if isPrivateIP(host) { return true }

        return false
    }

    /// Check if a hostname is a private/reserved IP address.
    private static func isPrivateIP(_ host: String) -> Bool {
        if host.hasPrefix("10.") { return true }
        if host.hasPrefix("192.168.") { return true }
        if host.hasPrefix("169.254.") { return true }
        if host.hasPrefix("127.") { return true }
        if host.hasPrefix("172.") {
            let parts = host.split(separator: ".")
            if parts.count >= 2, let second = Int(parts[1]) {
                return (16...31).contains(second)
            }
        }
        return false
    }
}
