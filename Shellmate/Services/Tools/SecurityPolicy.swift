import Foundation
import os

/// Security policy for path, URL, and shell command access.
enum SecurityPolicy {
    private static let logger = Logger(subsystem: "com.shellmate.app", category: "security")

    // MARK: - Path Blocklist

    /// Blocked path prefixes relative to home directory.
    private static let blockedHomePaths: [String] = [
        ".ssh", ".gnupg", ".gpg", ".aws", ".azure",
        ".config/gcloud", ".kube",
        ".docker/config.json",
        ".netrc", ".npmrc",
        ".config/gh",
        ".env",
        ".zshrc", ".zprofile", ".zshenv", ".zlogin", ".zlogout",
        ".bashrc", ".bash_profile", ".bash_login", ".profile",
        "Library/Keychains",
        "Library/LaunchAgents",
        "Library/LaunchDaemons",
    ]

    private static let blockedAbsolutePaths: [String] = [
        "/etc", "/System", "/Library", "/private",
        "/usr/local/etc",
    ]

    /// Check if a file path should be blocked.
    static func isPathBlocked(_ path: String) -> Bool {
        let standardized = URL(fileURLWithPath: path).standardized
        // Check both the standardized path and the symlink-resolved path.
        // We resolve the parent directory separately because resolvingSymlinksInPath
        // only resolves components that exist on disk.
        let resolved = standardized.resolvingSymlinksInPath().path
        let parentResolved = standardized.deletingLastPathComponent()
            .resolvingSymlinksInPath()
            .appendingPathComponent(standardized.lastPathComponent).path

        // Block if either the direct or resolved path matches
        return isResolvedPathBlocked(resolved) || isResolvedPathBlocked(parentResolved)
    }

    private static func isResolvedPathBlocked(_ resolved: String) -> Bool {
        // Check absolute path blocklist
        for blocked in blockedAbsolutePaths {
            if pathMatches(resolved, blockedPrefix: blocked) { return true }
        }

        // Check home-relative blocklist against both resolved and unresolved home
        let homeResolved = FileManager.default.homeDirectoryForCurrentUser
            .resolvingSymlinksInPath().path
        let homeStandard = FileManager.default.homeDirectoryForCurrentUser
            .standardized.path

        for home in Set([homeResolved, homeStandard]) {
            if resolved.hasPrefix(home) && resolved.count > home.count + 1 {
                let relative = String(resolved.dropFirst(home.count + 1))
                for blocked in blockedHomePaths {
                    if homePathMatches(relative, blockedPrefix: blocked) { return true }
                }
            }
        }

        return false
    }

    private static func pathMatches(_ path: String, blockedPrefix: String) -> Bool {
        path == blockedPrefix || path.hasPrefix(blockedPrefix + "/")
    }

    private static func homePathMatches(_ path: String, blockedPrefix: String) -> Bool {
        if blockedPrefix == ".env", path.hasPrefix(".env.") {
            return true
        }
        return pathMatches(path, blockedPrefix: blockedPrefix)
    }

    // MARK: - URL Blocklist

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
        let localhostNames: Set<String> = [
            "localhost", "0.0.0.0", "::1", "[::1]",
            "127.0.0.1", "[::ffff:127.0.0.1]",
        ]
        if localhostNames.contains(host) { return true }

        // Block private/reserved IP addresses
        if isPrivateOrReservedHost(host) { return true }

        return false
    }

    /// Check if a hostname resolves to or represents a private/reserved IP address.
    /// Handles dotted-decimal, IPv6, and numeric IP encodings.
    private static func isPrivateOrReservedHost(_ host: String) -> Bool {
        // Strip brackets from IPv6 addresses
        let cleaned = host.hasPrefix("[") && host.hasSuffix("]")
            ? String(host.dropFirst().dropLast())
            : host

        // Try parsing as IPv4
        var addr4 = in_addr()
        if inet_pton(AF_INET, cleaned, &addr4) == 1 {
            return isPrivateIPv4(addr4)
        }

        // Try parsing as IPv6
        var addr6 = in6_addr()
        if inet_pton(AF_INET6, cleaned, &addr6) == 1 {
            return isPrivateIPv6(addr6)
        }

        // Not a numeric IP — fall through to string-based checks for
        // decimal/hex encodings that inet_pton doesn't handle
        if let numericValue = UInt32(cleaned) {
            // Decimal IP like "2130706433" = 127.0.0.1
            let addr = in_addr(s_addr: numericValue.bigEndian)
            return isPrivateIPv4(addr)
        }
        if cleaned.hasPrefix("0x"), let numericValue = UInt32(cleaned.dropFirst(2), radix: 16) {
            let addr = in_addr(s_addr: numericValue.bigEndian)
            return isPrivateIPv4(addr)
        }

        return false
    }

    /// Check if an IPv4 address is private/reserved (RFC 1918, loopback, link-local).
    private static func isPrivateIPv4(_ addr: in_addr) -> Bool {
        let ip = UInt32(bigEndian: addr.s_addr)
        let b0 = (ip >> 24) & 0xFF
        let b1 = (ip >> 16) & 0xFF

        // 127.0.0.0/8 — loopback
        if b0 == 127 { return true }
        // 10.0.0.0/8 — private
        if b0 == 10 { return true }
        // 172.16.0.0/12 — private
        if b0 == 172 && (16...31).contains(b1) { return true }
        // 192.168.0.0/16 — private
        if b0 == 192 && b1 == 168 { return true }
        // 169.254.0.0/16 — link-local
        if b0 == 169 && b1 == 254 { return true }
        // 0.0.0.0/8
        if b0 == 0 { return true }

        return false
    }

    /// Check if an IPv6 address is private/reserved.
    private static func isPrivateIPv6(_ addr: in6_addr) -> Bool {
        let bytes = withUnsafeBytes(of: addr.__u6_addr.__u6_addr8) { Array($0) }

        // ::1 — loopback
        if bytes[0...14].allSatisfy({ $0 == 0 }) && bytes[15] == 1 { return true }
        // :: — unspecified
        if bytes.allSatisfy({ $0 == 0 }) { return true }
        // fe80::/10 — link-local
        if bytes[0] == 0xFE && (bytes[1] & 0xC0) == 0x80 { return true }
        // fc00::/7 — unique local (includes fd00::/8)
        if (bytes[0] & 0xFE) == 0xFC { return true }
        // ::ffff:0:0/96 — IPv4-mapped (check the embedded IPv4)
        if bytes[0...9].allSatisfy({ $0 == 0 }) && bytes[10] == 0xFF && bytes[11] == 0xFF {
            var embedded = in_addr()
            embedded.s_addr = UInt32(bytes[12]) << 24 | UInt32(bytes[13]) << 16
                | UInt32(bytes[14]) << 8 | UInt32(bytes[15])
            embedded.s_addr = embedded.s_addr.bigEndian
            return isPrivateIPv4(embedded)
        }

        return false
    }

    // MARK: - Shell Command Security

    /// Dangerous shell command patterns that should be blocked.
    private static let blockedCommandPatterns: [String] = [
        "sudo ", "sudo\t",
        "rm -rf /",
        "mkfs.", "dd if=",
        "> /dev/sd", "> /dev/disk",
        "chmod 777 /",
        ":(){ :|:& };:",  // fork bomb
    ]

    /// Paths that shell commands should not access (same as file blocklist).
    private static let blockedShellPathPatterns: [String] = [
        ".ssh/", ".gnupg/", ".gpg/", ".aws/", ".azure/",
        ".kube/", ".docker/config",
        "Library/Keychains", "Library/LaunchAgents", "Library/LaunchDaemons",
    ]

    /// Check if a shell command contains dangerous patterns.
    /// Returns a description of the blocked pattern if found, nil if allowed.
    static func checkShellCommand(_ command: String) -> String? {
        let lower = command.lowercased()

        for pattern in blockedCommandPatterns {
            if lower.contains(pattern) {
                logger.warning("Blocked shell command pattern: \(pattern)")
                return "Command contains blocked pattern: \(pattern.trimmingCharacters(in: .whitespaces))"
            }
        }

        // Check for access to sensitive paths through shell
        for pathPattern in blockedShellPathPatterns {
            if command.contains(pathPattern) {
                logger.warning("Shell command accesses blocked path: \(pathPattern)")
                return "Command accesses restricted path: \(pathPattern)"
            }
        }

        return nil
    }
}
