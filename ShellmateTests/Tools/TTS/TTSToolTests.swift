import Testing
import Foundation
@testable import Shellmate

@Suite("TTSProvider Tools")
struct TTSToolTests {

    private static let shell = ShellService()

    // MARK: - TTSSpeakTool

    @Suite("TTSSpeakTool")
    struct TTSSpeakToolTests {

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = TTSSpeakTool(shellService: shell)
            #expect(tool.identifier == "tts_speak")
            #expect(tool.category == .tts)
            #expect(tool.actionTier == .write)
            #expect(!tool.toolDescription.isEmpty)
        }

        @Test("requires text parameter")
        func requiresText() async throws {
            let tool = TTSSpeakTool(shellService: shell)
            let result = try await tool.execute(parameters: [:])
            #expect(result.isError)
            #expect(result.content.contains("text"))
        }

        @Test("rejects empty text")
        func rejectsEmptyText() async throws {
            let tool = TTSSpeakTool(shellService: shell)
            let result = try await tool.execute(parameters: ["text": ""])
            #expect(result.isError)
            #expect(result.content.contains("empty"))
        }

        @Test("provides confirmation description")
        func confirmationDescription() {
            let tool = TTSSpeakTool(shellService: shell)
            let desc = tool.confirmationDescription(parameters: ["text": "Hello world"])
            #expect(desc.contains("Hello world"))
        }
    }

    // MARK: - TTSVoicesTool

    @Suite("TTSVoicesTool")
    struct TTSVoicesToolTests {

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = TTSVoicesTool(shellService: shell)
            #expect(tool.identifier == "tts_voices")
            #expect(tool.category == .tts)
            #expect(tool.actionTier == .read)
        }

        @Test("lists available voices")
        func listsVoices() async throws {
            let tool = TTSVoicesTool(shellService: shell)
            let result = try await tool.execute(parameters: [:])
            #expect(!result.isError)
            #expect(!result.content.isEmpty)
            // macOS always has some voices
            #expect(result.content.contains("en_"))
        }
    }

    // MARK: - TTSProvider

    @Suite("TTSProvider")
    struct TTSProviderTests {

        @Test("provider has correct category and tool count")
        func providerMetadata() {
            let provider = TTSProvider(shellService: shell)
            #expect(provider.category == .tts)
            #expect(provider.displayName == "Text to Speech")
            #expect(provider.tools.count == 2)
        }

        @Test("provider contains all expected tool identifiers")
        func providerToolIdentifiers() {
            let provider = TTSProvider(shellService: shell)
            let ids = Set(provider.tools.map(\.identifier))
            #expect(ids.contains("tts_speak"))
            #expect(ids.contains("tts_voices"))
        }
    }
}
