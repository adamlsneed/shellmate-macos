import Testing
import Foundation
@testable import Shellmate

@Suite("AudioProvider Tools")
struct AudioToolTests {

    // MARK: - AudioVolumeTool

    @Suite("AudioVolumeTool")
    struct AudioVolumeToolTests {

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = AudioVolumeTool(shellService: ShellService())
            #expect(tool.identifier == "audio_volume")
            #expect(tool.category == .audio)
            #expect(tool.actionTier == .write)
            #expect(!tool.toolDescription.isEmpty)
        }

        @Test("get returns volume value")
        func getReturnsVolume() async throws {
            let tool = AudioVolumeTool(shellService: ShellService())
            let result = try await tool.execute(parameters: ["action": "get"])
            #expect(!result.isError)
            #expect(result.content.contains("volume") || result.content.contains("Volume"))
        }

        @Test("requires action parameter")
        func requiresAction() async throws {
            let tool = AudioVolumeTool(shellService: ShellService())
            let result = try await tool.execute(parameters: [:])
            #expect(result.isError)
            #expect(result.content.contains("action"))
        }

        @Test("set rejects invalid level")
        func rejectsInvalidLevel() async throws {
            let tool = AudioVolumeTool(shellService: ShellService())
            let result = try await tool.execute(parameters: ["action": "set", "level": 150])
            #expect(result.isError)
            #expect(result.content.contains("between"))
        }

        @Test("set requires level parameter")
        func setRequiresLevel() async throws {
            let tool = AudioVolumeTool(shellService: ShellService())
            let result = try await tool.execute(parameters: ["action": "set"])
            #expect(result.isError)
            #expect(result.content.contains("level"))
        }

        @Test("provides confirmation description")
        func confirmationDescription() {
            let tool = AudioVolumeTool(shellService: ShellService())
            let desc = tool.confirmationDescription(parameters: ["action": "mute"])
            #expect(desc.contains("Mute"))
        }
    }

    // MARK: - AudioInputOutputTool

    @Suite("AudioInputOutputTool")
    struct AudioInputOutputToolTests {

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = AudioInputOutputTool(shellService: ShellService())
            #expect(tool.identifier == "audio_input_output")
            #expect(tool.category == .audio)
            #expect(tool.actionTier == .read)
        }

        @Test("lists audio devices")
        func listsDevices() async throws {
            let tool = AudioInputOutputTool(shellService: ShellService())
            let result = try await tool.execute(parameters: [:])
            #expect(!result.isError)
            #expect(!result.content.isEmpty)
        }
    }

    // MARK: - AudioNowPlayingTool

    @Suite("AudioNowPlayingTool")
    struct AudioNowPlayingToolTests {

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = AudioNowPlayingTool(shellService: ShellService())
            #expect(tool.identifier == "audio_now_playing")
            #expect(tool.category == .audio)
            #expect(tool.actionTier == .read)
        }

        @Test("returns a result")
        func returnsResult() async throws {
            let tool = AudioNowPlayingTool(shellService: ShellService())
            let result = try await tool.execute(parameters: [:])
            #expect(!result.isError)
            // Should either show now playing info or "Nothing is currently playing."
            #expect(!result.content.isEmpty)
        }
    }

    // MARK: - AudioPlaybackControlTool

    @Suite("AudioPlaybackControlTool")
    struct AudioPlaybackControlToolTests {

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = AudioPlaybackControlTool(shellService: ShellService())
            #expect(tool.identifier == "audio_playback_control")
            #expect(tool.category == .audio)
            #expect(tool.actionTier == .write)
        }

        @Test("requires action parameter")
        func requiresAction() async throws {
            let tool = AudioPlaybackControlTool(shellService: ShellService())
            let result = try await tool.execute(parameters: [:])
            #expect(result.isError)
            #expect(result.content.contains("action"))
        }

        @Test("rejects invalid action")
        func rejectsInvalidAction() async throws {
            let tool = AudioPlaybackControlTool(shellService: ShellService())
            let result = try await tool.execute(parameters: ["action": "rewind"])
            #expect(result.isError)
            #expect(result.content.contains("Invalid"))
        }

        @Test("provides confirmation description")
        func confirmationDescription() {
            let tool = AudioPlaybackControlTool(shellService: ShellService())
            let desc = tool.confirmationDescription(parameters: ["action": "next"])
            #expect(desc.contains("next"))
        }
    }

    // MARK: - AudioProvider

    @Suite("AudioProvider")
    struct AudioProviderTests {

        @Test("provider has correct category and tool count")
        func providerMetadata() {
            let provider = AudioProvider(shellService: ShellService())
            #expect(provider.category == .audio)
            #expect(provider.displayName == "Audio & Volume")
            #expect(provider.tools.count == 4)
        }

        @Test("provider contains all expected tool identifiers")
        func providerToolIdentifiers() {
            let provider = AudioProvider(shellService: ShellService())
            let ids = Set(provider.tools.map(\.identifier))
            #expect(ids.contains("audio_volume"))
            #expect(ids.contains("audio_input_output"))
            #expect(ids.contains("audio_now_playing"))
            #expect(ids.contains("audio_playback_control"))
        }
    }
}
