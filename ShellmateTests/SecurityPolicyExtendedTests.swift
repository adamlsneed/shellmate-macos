import Testing; import Foundation; @testable import Shellmate
@Suite("SecurityPolicy (extended)") struct SecurityPolicyExtendedTests {
    let home=FileManager.default.homeDirectoryForCurrentUser.path
    @Test("more blocked") func mp() { #expect(SecurityPolicy.isPathBlocked("\(home)/.azure/x")); #expect(SecurityPolicy.isPathBlocked("\(home)/.kube/config")); #expect(SecurityPolicy.isPathBlocked("/private/etc/passwd")) }
    @Test("allows /usr/local/bin") func a() { #expect(!SecurityPolicy.isPathBlocked("/usr/local/bin/python3")) }
    @Test("dot-dot") func dd() { #expect(SecurityPolicy.isPathBlocked("\(home)/Documents/../.ssh/id_rsa")) }
    @Test("private IPs") func pi() { for u in ["http://10.0.0.1","http://172.16.0.1","http://192.168.1.1","http://169.254.1.1","http://127.0.0.1"]{#expect(SecurityPolicy.isURLBlocked(u))} }
    @Test("allows 172.32") func a172() { #expect(!SecurityPolicy.isURLBlocked("http://172.32.0.1")) }
    @Test("non-HTTP") func nh() { for u in ["ftp://x.com","file:///etc/passwd"]{#expect(SecurityPolicy.isURLBlocked(u))} }
    @Test("malformed") func mf() { #expect(SecurityPolicy.isURLBlocked("")); #expect(SecurityPolicy.isURLBlocked("not a url")) }
}
