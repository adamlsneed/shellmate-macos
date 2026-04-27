import Testing
import AppKit
import Foundation
@testable import Shellmate

@Suite("ClipboardProvider Tools", .serialized)
struct ClipboardToolTests {

    // MARK: - ClipboardReadTool

    @Suite("ClipboardReadTool")
    struct ClipboardReadToolTests {

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = ClipboardReadTool()
            #expect(tool.identifier == "clipboard_read")
            #expect(tool.category == .clipboard)
            #expect(tool.actionTier == .read)
            #expect(!tool.toolDescription.isEmpty)
        }

        @Test("returns non-error result")
        func readsContent() async throws {
            let tool = ClipboardReadTool()
            let result = try await tool.execute(parameters: [:])
            #expect(!result.isError)
            // In a headless test runner, pasteboard may be empty or have content —
            // either way the tool should return a non-error result.
            #expect(!result.content.isEmpty)
        }

        @Test("handles empty pasteboard gracefully")
        func readsEmptyPasteboard() async throws {
            await MainActor.run {
                _ = NSPasteboard.general.clearContents()
            }

            let tool = ClipboardReadTool()
            let result = try await tool.execute(parameters: [:])
            #expect(!result.isError)
            // Should mention empty or clipboard — not crash
            #expect(result.content.contains("empty") || result.content.contains("Clipboard") || result.content.contains("clipboard"))
        }
    }

    // MARK: - ClipboardWriteTool

    @Suite("ClipboardWriteTool")
    struct ClipboardWriteToolTests {

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = ClipboardWriteTool()
            #expect(tool.identifier == "clipboard_write")
            #expect(tool.category == .clipboard)
            #expect(tool.actionTier == .write)
        }

        @Test("returns success with character count")
        func writesContent() async throws {
            let tool = ClipboardWriteTool()
            let result = try await tool.execute(parameters: ["text": "Hello"])
            #expect(!result.isError)
            #expect(result.content.contains("5"))
            #expect(result.content.contains("clipboard"))
        }

        @Test("requires text parameter")
        func requiresText() async throws {
            let tool = ClipboardWriteTool()
            let result = try await tool.execute(parameters: [:])
            #expect(result.isError)
            #expect(result.content.contains("text"))
        }

        @Test("provides confirmation description")
        func confirmationDescription() {
            let tool = ClipboardWriteTool()
            let desc = tool.confirmationDescription(parameters: ["text": "Hello world"])
            #expect(desc.contains("Hello world"))
        }
    }

    // MARK: - ClipboardClearTool

    @Suite("ClipboardClearTool")
    struct ClipboardClearToolTests {

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = ClipboardClearTool()
            #expect(tool.identifier == "clipboard_clear")
            #expect(tool.category == .clipboard)
            #expect(tool.actionTier == .write)
        }

        @Test("returns success on clear")
        func clearsContent() async throws {
            let tool = ClipboardClearTool()
            let result = try await tool.execute(parameters: [:])
            #expect(!result.isError)
            #expect(result.content.contains("cleared"))
        }

        @Test("provides confirmation description")
        func confirmationDescription() {
            let tool = ClipboardClearTool()
            let desc = tool.confirmationDescription(parameters: [:])
            #expect(!desc.isEmpty)
        }
    }

    // MARK: - ClipboardProvider

    @Suite("ClipboardProvider")
    struct ClipboardProviderTests {

        @Test("provider has correct category and tool count")
        func providerMetadata() {
            let provider = ClipboardProvider()
            #expect(provider.category == .clipboard)
            #expect(provider.displayName == "Clipboard")
            #expect(provider.tools.count == 3)
        }

        @Test("provider contains all expected tool identifiers")
        func providerToolIdentifiers() {
            let provider = ClipboardProvider()
            let ids = Set(provider.tools.map(\.identifier))
            #expect(ids.contains("clipboard_read"))
            #expect(ids.contains("clipboard_write"))
            #expect(ids.contains("clipboard_clear"))
        }
    }
}
