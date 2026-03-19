import Testing
import Foundation
@testable import Shellmate

@Suite("SecurityPolicy (extended)") struct SecurityPolicyExtendedTests {
    let home = FileManager.default.homeDirectoryForCurrentUser.path
    @Test("blocks .azure") func t1() { #expect(SecurityPolicy.isPathBlocked("\(home)/.azure/creds")) }
    @Test("blocks .kube") func t2() { #expect(SecurityPolicy.isPathBlocked("\(home)/.kube/config")) }
    @Test("blocks /private") func t3() { #expect(SecurityPolicy.isPathBlocked("/private/etc/passwd")) }
    @Test("allows Downloads") func t4() { #expect(!SecurityPolicy.isPathBlocked("\(home)/Downloads/f.pdf")) }
    @Test("dot-dot escape") func t5() { #expect(SecurityPolicy.isPathBlocked("\(home)/Documents/../.ssh/id_rsa")) }
    @Test("blocks 0.0.0.0") func u1() { #expect(SecurityPolicy.isURLBlocked("http://0.0.0.0:8080")) }
    @Test("blocks 172.16-31") func u2() { #expect(SecurityPolicy.isURLBlocked("http://172.16.0.1")) }
    @Test("allows 172.32") func u3() { #expect(!SecurityPolicy.isURLBlocked("http://172.32.0.1")) }
    @Test("blocks ftp") func u4() { #expect(SecurityPolicy.isURLBlocked("ftp://example.com")) }
    @Test("allows HTTPS") func u5() { #expect(!SecurityPolicy.isURLBlocked("https://example.com")) }
    @Test("blocks malformed") func u6() { #expect(SecurityPolicy.isURLBlocked("not a url")) }
}
