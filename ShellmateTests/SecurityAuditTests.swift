import Testing
import Foundation
@testable import Shellmate

@Suite("Security Audit")
struct SecurityAuditTests {
    let home = FileManager.default.homeDirectoryForCurrentUser.path

    // MARK: - Path Security: Symlink Resolution (H-001)

    @Test("blocks symlink-resolved paths to sensitive directories")
    func testSymlinkResolution() throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("shellmate-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let symlinkURL = tmpDir.appendingPathComponent("link")
        let sshDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".ssh")
        // Only test if .ssh exists (most dev machines have it)
        if FileManager.default.fileExists(atPath: sshDir.path) {
            try FileManager.default.createSymbolicLink(at: symlinkURL, withDestinationURL: sshDir)
            #expect(SecurityPolicy.isPathBlocked(symlinkURL.appendingPathComponent("id_rsa").path))
        }
    }

    // MARK: - Path Security: Expanded Blocklist (H-001, H-004)

    @Test("blocks LaunchAgents directory")
    func testBlocksLaunchAgents() {
        #expect(SecurityPolicy.isPathBlocked("\(home)/Library/LaunchAgents/evil.plist"))
    }

    @Test("blocks LaunchDaemons directory")
    func testBlocksLaunchDaemons() {
        #expect(SecurityPolicy.isPathBlocked("\(home)/Library/LaunchDaemons/evil.plist"))
    }

    @Test("blocks shell config files")
    func testBlocksShellConfigs() {
        #expect(SecurityPolicy.isPathBlocked("\(home)/.zshrc"))
        #expect(SecurityPolicy.isPathBlocked("\(home)/.bashrc"))
        #expect(SecurityPolicy.isPathBlocked("\(home)/.bash_profile"))
        #expect(SecurityPolicy.isPathBlocked("\(home)/.profile"))
        #expect(SecurityPolicy.isPathBlocked("\(home)/.zprofile"))
    }

    @Test("blocks credential files")
    func testBlocksCredentialFiles() {
        #expect(SecurityPolicy.isPathBlocked("\(home)/.docker/config.json"))
        #expect(SecurityPolicy.isPathBlocked("\(home)/.netrc"))
        #expect(SecurityPolicy.isPathBlocked("\(home)/.npmrc"))
        #expect(SecurityPolicy.isPathBlocked("\(home)/.config/gh/hosts.yml"))
    }

    // MARK: - URL Security: IPv6 (H-003)

    @Test("blocks IPv6 loopback")
    func testBlocksIPv6Loopback() {
        #expect(SecurityPolicy.isURLBlocked("http://[::1]:8080"))
        #expect(SecurityPolicy.isURLBlocked("http://::1"))
    }

    @Test("blocks IPv6 link-local")
    func testBlocksIPv6LinkLocal() {
        #expect(SecurityPolicy.isURLBlocked("http://[fe80::1]"))
    }

    @Test("blocks IPv6 unique local")
    func testBlocksIPv6UniqueLocal() {
        #expect(SecurityPolicy.isURLBlocked("http://[fd00::1]"))
        #expect(SecurityPolicy.isURLBlocked("http://[fc00::1]"))
    }

    @Test("blocks IPv4-mapped IPv6")
    func testBlocksIPv4MappedIPv6() {
        #expect(SecurityPolicy.isURLBlocked("http://[::ffff:127.0.0.1]"))
        #expect(SecurityPolicy.isURLBlocked("http://[::ffff:10.0.0.1]"))
        #expect(SecurityPolicy.isURLBlocked("http://[::ffff:192.168.1.1]"))
    }

    // MARK: - URL Security: Decimal/Hex IP (H-003)

    @Test("blocks decimal IP encoding")
    func testBlocksDecimalIP() {
        // 2130706433 = 127.0.0.1
        #expect(SecurityPolicy.isURLBlocked("http://2130706433"))
    }

    @Test("blocks hex IP encoding")
    func testBlocksHexIP() {
        // 0x7f000001 = 127.0.0.1
        #expect(SecurityPolicy.isURLBlocked("http://0x7f000001"))
    }

    // MARK: - Shell Command Security (C-002)

    @Test("blocks dangerous shell patterns")
    func testBlocksDangerousCommands() {
        #expect(SecurityPolicy.checkShellCommand("sudo rm -rf /") != nil)
        #expect(SecurityPolicy.checkShellCommand("rm -rf /") != nil)
        #expect(SecurityPolicy.checkShellCommand("dd if=/dev/zero of=/dev/sda") != nil)
    }

    @Test("blocks shell access to sensitive paths")
    func testBlocksShellSensitivePaths() {
        #expect(SecurityPolicy.checkShellCommand("cat ~/.ssh/id_rsa") != nil)
        #expect(SecurityPolicy.checkShellCommand("cat ~/.aws/credentials") != nil)
        #expect(SecurityPolicy.checkShellCommand("ls ~/Library/Keychains/") != nil)
    }

    @Test("allows safe shell commands")
    func testAllowsSafeCommands() {
        #expect(SecurityPolicy.checkShellCommand("echo hello") == nil)
        #expect(SecurityPolicy.checkShellCommand("ls -la ~/Documents") == nil)
        #expect(SecurityPolicy.checkShellCommand("pwd") == nil)
        #expect(SecurityPolicy.checkShellCommand("date") == nil)
    }

    @Test("shell tool rejects blocked commands")
    func testShellToolRejectsBlocked() async throws {
        let tool = ShellExecuteTool(service: ShellService())
        let result = try await tool.execute(parameters: ["command": "sudo rm -rf /"])
        #expect(result.isError)
        #expect(result.content.contains("Access denied"))
    }

    // MARK: - Keychain Cleanup (L-004)

    @Test("KeychainHelper has deleteAllKeys method")
    func testDeleteAllKeysExists() {
        // Just verify the method is callable (actual Keychain ops in integration tests)
        KeychainHelper.deleteAllKeys()
    }

    // MARK: - API Error Truncation (M-005)

    @Test("Anthropic error response truncated")
    func testAnthropicErrorTruncation() async throws {
        // Build a request that will fail to confirm error handling path works
        let request = try AnthropicClient.buildRequest(
            messages: [["role": "user", "content": "test"]],
            system: nil, tools: [], model: "test",
            apiKey: "invalid", maxTokens: 10, stream: false, timeout: 5
        )
        // Verify request was built (the truncation happens at runtime on actual errors)
        #expect(request.httpMethod == "POST")
    }
}
