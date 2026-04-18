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
        // An attacker might try to break out of a string with embedded quotes
        let malicious = "foo\" & do shell script \"rm -rf /\""
        let sanitized = AppleScriptService.sanitize(malicious)
        // All 3 double quotes in the input must be escaped
        let escapedQuoteCount = sanitized.components(separatedBy: "\\\"").count - 1
        #expect(escapedQuoteCount == 3)
        // The sanitized string should not allow breaking out of an AppleScript string literal
        #expect(sanitized == "foo\\\" & do shell script \\\"rm -rf /\\\"")
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

    // MARK: - Sanitize edge cases (Phase D regression coverage)

    @Test("sanitize handles empty input")
    func sanitizeEmpty() {
        #expect(AppleScriptService.sanitize("") == "")
    }

    @Test("sanitize escapes a lone backslash")
    func sanitizeLoneBackslash() {
        #expect(AppleScriptService.sanitize(#"\"#) == #"\\"#)
    }

    @Test("sanitize escapes a lone quote")
    func sanitizeLoneQuote() {
        #expect(AppleScriptService.sanitize(#"""#) == #"\""#)
    }

    @Test("sanitize escapes backslashes BEFORE quotes (no double-escape)")
    func sanitizeOrderingMatters() {
        // Input: backslash-quote. If we escaped quotes first we'd produce
        // `\\\"` with a stray escape ambiguity; the implementation does
        // backslashes first → `\\\\` then quote → `\\\\\"`.
        let input = #"\""#
        let expected = #"\\\""#
        #expect(AppleScriptService.sanitize(input) == expected)
    }

    @Test("sanitize is idempotent on alphanumeric input")
    func sanitizeIdempotentOnSafe() {
        let input = "user.name+tag@example.com"
        #expect(AppleScriptService.sanitize(input) == input)
    }

    @Test("sanitize preserves newlines (AppleScript string literals allow them)")
    func sanitizePreservesNewlines() {
        // We don't escape \n — AppleScript string literals tolerate them when
        // the surrounding context permits. This behavior is intentional and
        // pinned here so changes to it are deliberate.
        let input = "line1\nline2"
        #expect(AppleScriptService.sanitize(input) == input)
    }

    @Test("sanitize handles emoji unchanged")
    func sanitizeEmoji() {
        let input = "Hello 👋 world 🌍"
        #expect(AppleScriptService.sanitize(input) == input)
    }

    @Test("sanitize handles a realistic injection attempt with multi-quote payload")
    func sanitizeMultiQuoteInjection() {
        let payload = #"foo" & (do shell script "rm -rf ~") & ""#
        let result = AppleScriptService.sanitize(payload)
        // Every double quote in the input must end up escaped.
        let originalQuoteCount = payload.filter { $0 == "\"" }.count
        let escapedSequenceCount = result.components(separatedBy: "\\\"").count - 1
        #expect(escapedSequenceCount == originalQuoteCount)
        // And the result must NOT contain a bare unescaped quote.
        var prev: Character = " "
        var foundBareQuote = false
        for c in result {
            if c == "\"" && prev != "\\" { foundBareQuote = true; break }
            prev = c
        }
        #expect(!foundBareQuote)
    }

    @Test("sanitize handles long input without truncation or corruption")
    func sanitizeLongInput() {
        // 5-char unit: a, ", b, \, c. After sanitize: a, \, ", b, \, \, c → 7 chars.
        let input = String(repeating: "a\"b\\c", count: 10_000)
        let result = AppleScriptService.sanitize(input)
        #expect(result.count == 7 * 10_000)
    }
}
