import Testing
import Foundation
@testable import Shellmate

@Suite("NotesProvider Tools")
struct NotesToolTests {

    private static let appleScript = AppleScriptService(shellService: ShellService())

    // MARK: - NotesCreateTool

    @Suite("NotesCreateTool")
    struct NotesCreateToolTests {

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = NotesCreateTool(appleScriptService: appleScript)
            #expect(tool.identifier == "notes_create")
            #expect(tool.category == .notes)
            #expect(tool.actionTier == .write)
            #expect(!tool.toolDescription.isEmpty)
        }

        @Test("requires title parameter")
        func requiresTitle() async throws {
            let tool = NotesCreateTool(appleScriptService: appleScript)
            let result = try await tool.execute(parameters: ["body": "test"])
            #expect(result.isError)
            #expect(result.content.contains("title"))
        }

        @Test("requires body parameter")
        func requiresBody() async throws {
            let tool = NotesCreateTool(appleScriptService: appleScript)
            let result = try await tool.execute(parameters: ["title": "test"])
            #expect(result.isError)
            #expect(result.content.contains("body"))
        }

        @Test("provides confirmation description")
        func confirmationDescription() {
            let tool = NotesCreateTool(appleScriptService: appleScript)
            let desc = tool.confirmationDescription(parameters: ["title": "My Note"])
            #expect(desc.contains("My Note"))
        }
    }

    // MARK: - NotesSearchTool

    @Suite("NotesSearchTool")
    struct NotesSearchToolTests {

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = NotesSearchTool(appleScriptService: appleScript)
            #expect(tool.identifier == "notes_search")
            #expect(tool.category == .notes)
            #expect(tool.actionTier == .read)
        }

        @Test("requires query parameter")
        func requiresQuery() async throws {
            let tool = NotesSearchTool(appleScriptService: appleScript)
            let result = try await tool.execute(parameters: [:])
            #expect(result.isError)
            #expect(result.content.contains("query"))
        }
    }

    // MARK: - NotesReadTool

    @Suite("NotesReadTool")
    struct NotesReadToolTests {

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = NotesReadTool(appleScriptService: appleScript)
            #expect(tool.identifier == "notes_read")
            #expect(tool.category == .notes)
            #expect(tool.actionTier == .read)
        }

        @Test("requires name parameter")
        func requiresName() async throws {
            let tool = NotesReadTool(appleScriptService: appleScript)
            let result = try await tool.execute(parameters: [:])
            #expect(result.isError)
            #expect(result.content.contains("name"))
        }
    }

    // MARK: - NotesAppendTool

    @Suite("NotesAppendTool")
    struct NotesAppendToolTests {

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = NotesAppendTool(appleScriptService: appleScript)
            #expect(tool.identifier == "notes_append")
            #expect(tool.category == .notes)
            #expect(tool.actionTier == .write)
        }

        @Test("requires name parameter")
        func requiresName() async throws {
            let tool = NotesAppendTool(appleScriptService: appleScript)
            let result = try await tool.execute(parameters: ["text": "hello"])
            #expect(result.isError)
            #expect(result.content.contains("name"))
        }

        @Test("requires text parameter")
        func requiresText() async throws {
            let tool = NotesAppendTool(appleScriptService: appleScript)
            let result = try await tool.execute(parameters: ["name": "My Note"])
            #expect(result.isError)
            #expect(result.content.contains("text"))
        }

        @Test("provides confirmation description")
        func confirmationDescription() {
            let tool = NotesAppendTool(appleScriptService: appleScript)
            let desc = tool.confirmationDescription(parameters: ["name": "My Note"])
            #expect(desc.contains("My Note"))
        }
    }

    // MARK: - NotesListFoldersTool

    @Suite("NotesListFoldersTool")
    struct NotesListFoldersToolTests {

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = NotesListFoldersTool(appleScriptService: appleScript)
            #expect(tool.identifier == "notes_list_folders")
            #expect(tool.category == .notes)
            #expect(tool.actionTier == .read)
        }
    }

    // MARK: - NotesProvider

    @Suite("NotesProvider")
    struct NotesProviderTests {

        @Test("provider has correct category and tool count")
        func providerMetadata() {
            let provider = NotesProvider(appleScriptService: appleScript)
            #expect(provider.category == .notes)
            #expect(provider.displayName == "Notes")
            #expect(provider.tools.count == 5)
        }

        @Test("provider contains all expected tool identifiers")
        func providerToolIdentifiers() {
            let provider = NotesProvider(appleScriptService: appleScript)
            let ids = Set(provider.tools.map(\.identifier))
            #expect(ids.contains("notes_create"))
            #expect(ids.contains("notes_search"))
            #expect(ids.contains("notes_read"))
            #expect(ids.contains("notes_append"))
            #expect(ids.contains("notes_list_folders"))
        }

        @Test("provider requires appleEvents permission")
        func providerPermissions() {
            let provider = NotesProvider(appleScriptService: appleScript)
            #expect(provider.requiredPermissions.contains(.appleEvents))
        }
    }
}
