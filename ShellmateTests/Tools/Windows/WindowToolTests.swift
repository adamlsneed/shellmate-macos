import Testing
import Foundation
@testable import Shellmate

@Suite("WindowProvider Tools")
struct WindowToolTests {

    // MARK: - WindowListTool

    @Suite("WindowListTool")
    struct WindowListToolTests {

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = WindowListTool()
            #expect(tool.identifier == "window_list")
            #expect(tool.category == .windows)
            #expect(tool.actionTier == .read)
            #expect(!tool.toolDescription.isEmpty)
        }
    }

    // MARK: - WindowMoveTool

    @Suite("WindowMoveTool")
    struct WindowMoveToolTests {

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = WindowMoveTool()
            #expect(tool.identifier == "window_move")
            #expect(tool.category == .windows)
            #expect(tool.actionTier == .write)
        }

        @Test("requires app parameter")
        func requiresApp() async throws {
            let tool = WindowMoveTool()
            let result = try await tool.execute(parameters: ["x": 0, "y": 0])
            #expect(result.isError)
            #expect(result.content.contains("app"))
        }

        @Test("requires x parameter")
        func requiresX() async throws {
            let tool = WindowMoveTool()
            let result = try await tool.execute(parameters: ["app": "Finder", "y": 0])
            #expect(result.isError)
            #expect(result.content.contains("x"))
        }

        @Test("requires y parameter")
        func requiresY() async throws {
            let tool = WindowMoveTool()
            let result = try await tool.execute(parameters: ["app": "Finder", "x": 0])
            #expect(result.isError)
            #expect(result.content.contains("y"))
        }

        @Test("provides confirmation description")
        func confirmationDescription() {
            let tool = WindowMoveTool()
            let desc = tool.confirmationDescription(parameters: ["app": "Safari", "x": 100, "y": 200])
            #expect(desc.contains("Safari"))
        }
    }

    // MARK: - WindowResizeTool

    @Suite("WindowResizeTool")
    struct WindowResizeToolTests {

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = WindowResizeTool()
            #expect(tool.identifier == "window_resize")
            #expect(tool.category == .windows)
            #expect(tool.actionTier == .write)
        }

        @Test("requires app parameter")
        func requiresApp() async throws {
            let tool = WindowResizeTool()
            let result = try await tool.execute(parameters: ["width": 800, "height": 600])
            #expect(result.isError)
            #expect(result.content.contains("app"))
        }

        @Test("requires positive dimensions")
        func requiresPositiveDimensions() async throws {
            let tool = WindowResizeTool()
            let result = try await tool.execute(parameters: ["app": "Finder", "width": -1, "height": 600])
            #expect(result.isError)
            #expect(result.content.contains("positive"))
        }

        @Test("provides confirmation description")
        func confirmationDescription() {
            let tool = WindowResizeTool()
            let desc = tool.confirmationDescription(parameters: ["app": "Safari", "width": 800, "height": 600])
            #expect(desc.contains("Safari"))
            #expect(desc.contains("800"))
        }
    }

    // MARK: - WindowArrangeTool

    @Suite("WindowArrangeTool")
    struct WindowArrangeToolTests {

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = WindowArrangeTool()
            #expect(tool.identifier == "window_arrange")
            #expect(tool.category == .windows)
            #expect(tool.actionTier == .write)
        }

        @Test("requires app parameter")
        func requiresApp() async throws {
            let tool = WindowArrangeTool()
            let result = try await tool.execute(parameters: ["preset": "maximize"])
            #expect(result.isError)
            #expect(result.content.contains("app"))
        }

        @Test("requires preset parameter")
        func requiresPreset() async throws {
            let tool = WindowArrangeTool()
            let result = try await tool.execute(parameters: ["app": "Finder"])
            #expect(result.isError)
            #expect(result.content.contains("preset"))
        }

        @Test("rejects invalid preset")
        func rejectsInvalidPreset() async throws {
            let tool = WindowArrangeTool()
            let result = try await tool.execute(parameters: ["app": "Finder", "preset": "diagonal"])
            #expect(result.isError)
            #expect(result.content.contains("Invalid preset"))
        }

        @Test("provides confirmation description")
        func confirmationDescription() {
            let tool = WindowArrangeTool()
            let desc = tool.confirmationDescription(parameters: ["app": "Safari", "preset": "left_half"])
            #expect(desc.contains("Safari"))
            #expect(desc.contains("left_half"))
        }
    }

    // MARK: - WindowFocusTool

    @Suite("WindowFocusTool")
    struct WindowFocusToolTests {

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = WindowFocusTool()
            #expect(tool.identifier == "window_focus")
            #expect(tool.category == .windows)
            #expect(tool.actionTier == .write)
        }

        @Test("requires app parameter")
        func requiresApp() async throws {
            let tool = WindowFocusTool()
            let result = try await tool.execute(parameters: [:])
            #expect(result.isError)
            #expect(result.content.contains("app"))
        }

        @Test("returns error for non-running app")
        func nonRunningApp() async throws {
            let tool = WindowFocusTool()
            let result = try await tool.execute(parameters: ["app": "NonExistentApp12345"])
            #expect(result.isError)
            #expect(result.content.contains("not running"))
        }

        @Test("provides confirmation description")
        func confirmationDescription() {
            let tool = WindowFocusTool()
            let desc = tool.confirmationDescription(parameters: ["app": "Safari"])
            #expect(desc.contains("Safari"))
        }
    }

    // MARK: - WindowProvider

    @Suite("WindowProvider")
    struct WindowProviderTests {

        @Test("provider has correct category and tool count")
        func providerMetadata() {
            let provider = WindowProvider()
            #expect(provider.category == .windows)
            #expect(provider.displayName == "Window Management")
            #expect(provider.tools.count == 5)
        }

        @Test("provider contains all expected tool identifiers")
        func providerToolIdentifiers() {
            let provider = WindowProvider()
            let ids = Set(provider.tools.map(\.identifier))
            #expect(ids.contains("window_list"))
            #expect(ids.contains("window_move"))
            #expect(ids.contains("window_resize"))
            #expect(ids.contains("window_arrange"))
            #expect(ids.contains("window_focus"))
        }

        @Test("provider requires accessibility permission")
        func providerPermissions() {
            let provider = WindowProvider()
            #expect(provider.requiredPermissions.contains(.accessibility))
        }
    }
}
