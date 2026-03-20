import Testing
import Foundation
@testable import Shellmate

@Suite("AppleScriptService")
struct AppleScriptServiceTests {

    @Test("sanitize escapes backslashes and quotes")
    func sanitizeEscapes() {
        let result = AppleScriptService.sanitize(#"say "hello\" world"#)
        #expect(result == #"say \"hello\\\" world"#)
    }

    @Test("sanitize handles clean input unchanged")
    func sanitizeCleanInput() {
        let result = AppleScriptService.sanitize("Hello World")
        #expect(result == "Hello World")
    }

    @Test("sanitize blocks injection via embedded quotes")
    func sanitizeBlocksInjection() {
        // An attacker might try: foo" & do shell script "rm -rf /"
        let malicious = #"foo" & do shell script "rm -rf /"#
        let sanitized = AppleScriptService.sanitize(malicious)
        #expect(!sanitized.contains("\" &"))
        #expect(sanitized.contains("\\\""))
    }

    @Test("execute simple script returns result")
    func executeSimpleScript() async throws {
        let service = AppleScriptService(shellService: ShellService())
        let result = try await service.execute(script: "return 2 + 2")
        #expect(result == "4")
    }

    @Test("execute app command targets correct application")
    func executeAppCommand() async throws {
        let service = AppleScriptService(shellService: ShellService())
        // Finder is always available
        let result = try await service.execute(app: "Finder", command: "return name of startup disk")
        #expect(!result.isEmpty)
    }

    @Test("execute invalid script throws error")
    func executeInvalidScript() async throws {
        let service = AppleScriptService(shellService: ShellService())
        await #expect(throws: AppleScriptError.self) {
            _ = try await service.execute(script: "this is not valid applescript at all")
        }
    }
}
