import Testing
import Foundation
@testable import Shellmate

@Suite("DisplayProvider Tools")
struct DisplayToolTests {

    // MARK: - DisplayInfoTool

    @Suite("DisplayInfoTool")
    struct DisplayInfoToolTests {

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = DisplayInfoTool()
            #expect(tool.identifier == "display_info")
            #expect(tool.category == .display)
            #expect(tool.actionTier == .read)
            #expect(!tool.toolDescription.isEmpty)
        }

        @Test("returns resolution-like content")
        func executionReturnsDisplayInfo() async throws {
            let tool = DisplayInfoTool()
            let result = try await tool.execute(parameters: [:])
            // In headless/CI environments, no displays may be attached
            if !result.isError {
                #expect(result.content.contains("Display"))
                #expect(result.content.contains("x"))
            } else {
                // Graceful failure in headless environment
                #expect(result.content.contains("enumerate") || result.content.contains("display"))
            }
        }
    }

    // MARK: - DisplayBrightnessTool

    @Suite("DisplayBrightnessTool")
    struct DisplayBrightnessToolTests {

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = DisplayBrightnessTool(shellService: ShellService())
            #expect(tool.identifier == "display_brightness")
            #expect(tool.category == .display)
            #expect(tool.actionTier == .write)
        }

        @Test("get returns a value")
        func getReturnsBrightness() async throws {
            let tool = DisplayBrightnessTool(shellService: ShellService())
            let result = try await tool.execute(parameters: ["action": "get"])
            #expect(!result.isError)
            #expect(!result.content.isEmpty)
        }

        @Test("requires action parameter")
        func requiresAction() async throws {
            let tool = DisplayBrightnessTool(shellService: ShellService())
            let result = try await tool.execute(parameters: [:])
            #expect(result.isError)
            #expect(result.content.contains("action"))
        }

        @Test("set rejects invalid level")
        func rejectsInvalidLevel() async throws {
            let tool = DisplayBrightnessTool(shellService: ShellService())
            let result = try await tool.execute(parameters: ["action": "set", "level": 2.0])
            #expect(result.isError)
            #expect(result.content.contains("between"))
        }

        @Test("provides confirmation description for set")
        func confirmationDescription() {
            let tool = DisplayBrightnessTool(shellService: ShellService())
            let desc = tool.confirmationDescription(parameters: ["action": "set", "level": 0.75])
            #expect(desc.contains("75%"))
        }
    }

    // MARK: - DisplayDarkModeTool

    @Suite("DisplayDarkModeTool")
    struct DisplayDarkModeToolTests {

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = DisplayDarkModeTool(shellService: ShellService())
            #expect(tool.identifier == "display_dark_mode")
            #expect(tool.category == .display)
            #expect(tool.actionTier == .write)
        }

        @Test("get returns dark or light")
        func getReturnsMode() async throws {
            let tool = DisplayDarkModeTool(shellService: ShellService())
            let result = try await tool.execute(parameters: ["action": "get"])
            #expect(!result.isError)
            #expect(result.content.contains("Dark") || result.content.contains("Light"))
        }

        @Test("requires action parameter")
        func requiresAction() async throws {
            let tool = DisplayDarkModeTool(shellService: ShellService())
            let result = try await tool.execute(parameters: [:])
            #expect(result.isError)
            #expect(result.content.contains("action"))
        }

        @Test("set requires mode parameter")
        func setRequiresMode() async throws {
            let tool = DisplayDarkModeTool(shellService: ShellService())
            let result = try await tool.execute(parameters: ["action": "set"])
            #expect(result.isError)
            #expect(result.content.contains("mode"))
        }

        @Test("provides confirmation description for toggle")
        func confirmationDescriptionToggle() {
            let tool = DisplayDarkModeTool(shellService: ShellService())
            let desc = tool.confirmationDescription(parameters: ["action": "toggle"])
            #expect(desc.contains("Toggle"))
        }
    }

    // MARK: - DisplayProvider

    @Suite("DisplayProvider")
    struct DisplayProviderTests {

        @Test("provider has correct category and tool count")
        func providerMetadata() {
            let provider = DisplayProvider(shellService: ShellService())
            #expect(provider.category == .display)
            #expect(provider.displayName == "Display")
            #expect(provider.tools.count == 3)
        }

        @Test("provider contains all expected tool identifiers")
        func providerToolIdentifiers() {
            let provider = DisplayProvider(shellService: ShellService())
            let ids = Set(provider.tools.map(\.identifier))
            #expect(ids.contains("display_info"))
            #expect(ids.contains("display_brightness"))
            #expect(ids.contains("display_dark_mode"))
        }
    }
}
