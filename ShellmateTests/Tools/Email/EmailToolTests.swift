import Testing
import Foundation
@testable import Shellmate

@Suite("EmailProvider Tools")
struct EmailToolTests {

    private static let shell = ShellService()
    private static let appleScript = AppleScriptService(shellService: shell)

    // MARK: - EmailSearchTool

    @Suite("EmailSearchTool")
    struct EmailSearchToolTests {

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = EmailSearchTool(shellService: shell)
            #expect(tool.identifier == "email_search")
            #expect(tool.category == .email)
            #expect(tool.actionTier == .read)
            #expect(!tool.toolDescription.isEmpty)
        }

        @Test("requires query parameter")
        func requiresQuery() async throws {
            let tool = EmailSearchTool(shellService: shell)
            let result = try await tool.execute(parameters: [:])
            #expect(result.isError)
            #expect(result.content.contains("query"))
        }
    }

    // MARK: - EmailReadTool

    @Suite("EmailReadTool")
    struct EmailReadToolTests {

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = EmailReadTool(appleScriptService: appleScript)
            #expect(tool.identifier == "email_read")
            #expect(tool.category == .email)
            #expect(tool.actionTier == .read)
        }

        @Test("requires subject parameter")
        func requiresSubject() async throws {
            let tool = EmailReadTool(appleScriptService: appleScript)
            let result = try await tool.execute(parameters: [:])
            #expect(result.isError)
            #expect(result.content.contains("subject"))
        }
    }

    // MARK: - EmailComposeTool

    @Suite("EmailComposeTool")
    struct EmailComposeToolTests {

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = EmailComposeTool(appleScriptService: appleScript)
            #expect(tool.identifier == "email_compose")
            #expect(tool.category == .email)
            #expect(tool.actionTier == .write)
        }

        @Test("requires to parameter")
        func requiresTo() async throws {
            let tool = EmailComposeTool(appleScriptService: appleScript)
            let result = try await tool.execute(parameters: ["subject": "Test", "body": "Hello"])
            #expect(result.isError)
            #expect(result.content.contains("to"))
        }

        @Test("requires subject parameter")
        func requiresSubject() async throws {
            let tool = EmailComposeTool(appleScriptService: appleScript)
            let result = try await tool.execute(parameters: ["to": "test@test.com", "body": "Hello"])
            #expect(result.isError)
            #expect(result.content.contains("subject"))
        }

        @Test("requires body parameter")
        func requiresBody() async throws {
            let tool = EmailComposeTool(appleScriptService: appleScript)
            let result = try await tool.execute(parameters: ["to": "test@test.com", "subject": "Test"])
            #expect(result.isError)
            #expect(result.content.contains("body"))
        }

        @Test("provides confirmation description")
        func confirmationDescription() {
            let tool = EmailComposeTool(appleScriptService: appleScript)
            let desc = tool.confirmationDescription(parameters: ["to": "test@test.com", "subject": "Hello"])
            #expect(desc.contains("test@test.com"))
        }

        // MARK: - "Never sends" regression coverage (Phase D)

        @Test("rendered script never invokes Mail's send verb")
        func neverSendsBasic() {
            let script = EmailComposeTool.renderScript(
                to: "alice@example.com",
                subject: "Hi",
                body: "Hello",
                cc: nil
            )
            // The script must NEVER contain Mail's `send` keyword as a verb,
            // even after sanitize. Match it as a whole word so substrings like
            // "sender" don't trigger.
            #expect(!Self.containsAppleScriptVerb(script, verb: "send"))
        }

        @Test("rendered script with cc still never sends")
        func neverSendsWithCc() {
            let script = EmailComposeTool.renderScript(
                to: "a@b.com",
                subject: "X",
                body: "Y",
                cc: "c@d.com"
            )
            #expect(!Self.containsAppleScriptVerb(script, verb: "send"))
        }

        @Test("malicious subject cannot inject a send verb")
        func cannotInjectSendViaSubject() {
            // Classic break-out attempt: close the string, append a send command,
            // reopen. sanitize should escape the quote so the payload becomes
            // text inside the subject, not an AppleScript statement.
            let evilSubject = #"Hi"} \nsend newMsg \ntell application "Mail" to set foo to {bar:""#
            let script = EmailComposeTool.renderScript(
                to: "victim@example.com",
                subject: evilSubject,
                body: "body",
                cc: nil
            )
            #expect(!Self.containsAppleScriptVerb(script, verb: "send"))
        }

        @Test("malicious body cannot inject a send verb")
        func cannotInjectSendViaBody() {
            let evilBody = #"Hello"} activate ¬\nsend newMsg ¬\ntell application "Mail" to {x:""#
            let script = EmailComposeTool.renderScript(
                to: "victim@example.com",
                subject: "subject",
                body: evilBody,
                cc: nil
            )
            #expect(!Self.containsAppleScriptVerb(script, verb: "send"))
        }

        @Test("rendered script preserves the recipient verbatim after sanitize")
        func recipientPreservedAfterSanitize() {
            let script = EmailComposeTool.renderScript(
                to: "user.name+tag@example.com",
                subject: "S",
                body: "B",
                cc: nil
            )
            #expect(script.contains("user.name+tag@example.com"))
        }

        /// Returns true if the script contains the given AppleScript verb as a
        /// whole word (not as a substring of e.g. `sender` or `<verb>er`).
        /// Used to assert "never sends" guarantees.
        private static func containsAppleScriptVerb(_ script: String, verb: String) -> Bool {
            // Word boundary on both sides — alphanumerics and underscores
            // continue an identifier in AppleScript-ish syntax.
            let pattern = "(?:^|[^A-Za-z0-9_])\(NSRegularExpression.escapedPattern(for: verb))(?:$|[^A-Za-z0-9_])"
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
            let range = NSRange(script.startIndex..., in: script)
            return regex.firstMatch(in: script, range: range) != nil
        }
    }

    // MARK: - EmailSummarizeUnreadTool

    @Suite("EmailSummarizeUnreadTool")
    struct EmailSummarizeUnreadToolTests {

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = EmailSummarizeUnreadTool(appleScriptService: appleScript)
            #expect(tool.identifier == "email_summarize_unread")
            #expect(tool.category == .email)
            #expect(tool.actionTier == .read)
        }
    }

    // MARK: - EmailProvider

    @Suite("EmailProvider")
    struct EmailProviderTests {

        @Test("provider has correct category and tool count")
        func providerMetadata() {
            let provider = EmailProvider(shellService: shell, appleScriptService: appleScript)
            #expect(provider.category == .email)
            #expect(provider.displayName == "Email")
            #expect(provider.tools.count == 4)
        }

        @Test("provider contains all expected tool identifiers")
        func providerToolIdentifiers() {
            let provider = EmailProvider(shellService: shell, appleScriptService: appleScript)
            let ids = Set(provider.tools.map(\.identifier))
            #expect(ids.contains("email_search"))
            #expect(ids.contains("email_read"))
            #expect(ids.contains("email_compose"))
            #expect(ids.contains("email_summarize_unread"))
        }

        @Test("provider requires appleEvents permission")
        func providerPermissions() {
            let provider = EmailProvider(shellService: shell, appleScriptService: appleScript)
            #expect(provider.requiredPermissions.contains(.appleEvents))
        }
    }
}
