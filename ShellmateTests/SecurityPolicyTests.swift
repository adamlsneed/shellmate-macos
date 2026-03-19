import Testing
import Foundation
@testable import Shellmate

@Suite("SecurityPolicy")
struct SecurityPolicyTests {

    @Test("blocks sensitive home directory paths")
    func testBlockedHomePaths() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        #expect(SecurityPolicy.isPathBlocked("\(home)/.ssh/id_rsa"))
        #expect(SecurityPolicy.isPathBlocked("\(home)/.gnupg/trustdb.gpg"))
        #expect(SecurityPolicy.isPathBlocked("\(home)/.aws/credentials"))
        #expect(SecurityPolicy.isPathBlocked("\(home)/.env"))
    }

    @Test("blocks system paths")
    func testBlockedSystemPaths() {
        #expect(SecurityPolicy.isPathBlocked("/etc/passwd"))
        #expect(SecurityPolicy.isPathBlocked("/System/Library/Extensions"))
        #expect(SecurityPolicy.isPathBlocked("/Library/Preferences"))
    }

    @Test("allows normal paths")
    func testAllowedPaths() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        #expect(!SecurityPolicy.isPathBlocked("\(home)/Documents/test.txt"))
        #expect(!SecurityPolicy.isPathBlocked("\(home)/Desktop/notes.md"))
        #expect(!SecurityPolicy.isPathBlocked("/tmp/test"))
    }

    @Test("blocks private IPs and localhost")
    func testBlockedURLs() {
        #expect(SecurityPolicy.isURLBlocked("http://localhost:3000"))
        #expect(SecurityPolicy.isURLBlocked("http://127.0.0.1:8080"))
        #expect(SecurityPolicy.isURLBlocked("http://10.0.0.1"))
        #expect(SecurityPolicy.isURLBlocked("http://192.168.1.1"))
        #expect(SecurityPolicy.isURLBlocked("http://172.16.0.1"))
        #expect(SecurityPolicy.isURLBlocked("ftp://example.com"))
    }

    @Test("allows public URLs")
    func testAllowedURLs() {
        #expect(!SecurityPolicy.isURLBlocked("https://example.com"))
        #expect(!SecurityPolicy.isURLBlocked("https://api.anthropic.com/v1/messages"))
        #expect(!SecurityPolicy.isURLBlocked("http://brave.com"))
    }
}
