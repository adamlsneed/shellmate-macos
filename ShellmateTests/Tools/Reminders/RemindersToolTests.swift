import Foundation
import Testing
@testable import Shellmate

@Suite("RemindersProvider Tools")
struct RemindersToolTests {

    // MARK: - RemindersCreateTool

    @Suite("RemindersCreateTool")
    struct RemindersCreateToolTests {
        private let service = RemindersService()

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = RemindersCreateTool(service: service)
            #expect(tool.identifier == "reminders_create")
            #expect(tool.category == .reminders)
            #expect(tool.actionTier == .write)
            #expect(!tool.toolDescription.isEmpty)
        }

        @Test("schema requires title")
        func schemaRequiredParams() {
            let tool = RemindersCreateTool(service: service)
            #expect(tool.parameterSchema.required.contains("title"))
        }

        @Test("returns error for missing title")
        func missingTitle() async throws {
            let tool = RemindersCreateTool(service: service)
            let result = try await tool.execute(parameters: [:])
            #expect(result.isError)
            #expect(result.content.contains("title"))
        }

        @Test("returns error for unparseable due_date")
        func unparseableDueDate() async throws {
            let tool = RemindersCreateTool(service: service)
            let result = try await tool.execute(parameters: [
                "title": "Test",
                "due_date": "not a real date xyz",
            ])
            #expect(result.isError)
            #expect(result.content.contains("parse"))
        }

        @Test("provides non-empty confirmation description")
        func confirmationDescription() {
            let tool = RemindersCreateTool(service: service)
            let desc = tool.confirmationDescription(parameters: ["title": "Buy groceries"])
            #expect(desc.contains("Buy groceries"))
        }
    }

    // MARK: - RemindersListTool

    @Suite("RemindersListTool")
    struct RemindersListToolTests {
        private let service = RemindersService()

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = RemindersListTool(service: service)
            #expect(tool.identifier == "reminders_list")
            #expect(tool.category == .reminders)
            #expect(tool.actionTier == .read)
            #expect(!tool.toolDescription.isEmpty)
        }

        @Test("schema has no required params")
        func schemaNoRequired() {
            let tool = RemindersListTool(service: service)
            #expect(tool.parameterSchema.required.isEmpty)
        }
    }

    // MARK: - RemindersCompleteTool

    @Suite("RemindersCompleteTool")
    struct RemindersCompleteToolTests {
        private let service = RemindersService()

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = RemindersCompleteTool(service: service)
            #expect(tool.identifier == "reminders_complete")
            #expect(tool.category == .reminders)
            #expect(tool.actionTier == .write)
            #expect(!tool.toolDescription.isEmpty)
        }

        @Test("returns error for missing search_query")
        func missingSearchQuery() async throws {
            let tool = RemindersCompleteTool(service: service)
            let result = try await tool.execute(parameters: [:])
            #expect(result.isError)
            #expect(result.content.contains("search_query"))
        }

        @Test("provides non-empty confirmation description")
        func confirmationDescription() {
            let tool = RemindersCompleteTool(service: service)
            let desc = tool.confirmationDescription(parameters: ["search_query": "groceries"])
            #expect(desc.contains("groceries"))
        }
    }

    // MARK: - RemindersModifyTool

    @Suite("RemindersModifyTool")
    struct RemindersModifyToolTests {
        private let service = RemindersService()

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = RemindersModifyTool(service: service)
            #expect(tool.identifier == "reminders_modify")
            #expect(tool.category == .reminders)
            #expect(tool.actionTier == .write)
            #expect(!tool.toolDescription.isEmpty)
        }

        @Test("schema requires search_query")
        func schemaRequiredParams() {
            let tool = RemindersModifyTool(service: service)
            #expect(tool.parameterSchema.required.contains("search_query"))
        }

        @Test("returns error for missing search_query")
        func missingSearchQuery() async throws {
            let tool = RemindersModifyTool(service: service)
            let result = try await tool.execute(parameters: [:])
            #expect(result.isError)
            #expect(result.content.contains("search_query"))
        }

        @Test("provides non-empty confirmation description")
        func confirmationDescription() {
            let tool = RemindersModifyTool(service: service)
            let desc = tool.confirmationDescription(parameters: ["search_query": "groceries"])
            #expect(desc.contains("groceries"))
        }
    }

    // MARK: - RemindersDeleteTool

    @Suite("RemindersDeleteTool")
    struct RemindersDeleteToolTests {
        private let service = RemindersService()

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = RemindersDeleteTool(service: service)
            #expect(tool.identifier == "reminders_delete")
            #expect(tool.category == .reminders)
            #expect(tool.actionTier == .destructive)
            #expect(!tool.toolDescription.isEmpty)
        }

        @Test("returns error for missing search_query")
        func missingSearchQuery() async throws {
            let tool = RemindersDeleteTool(service: service)
            let result = try await tool.execute(parameters: [:])
            #expect(result.isError)
            #expect(result.content.contains("search_query"))
        }

        @Test("provides non-empty confirmation description")
        func confirmationDescription() {
            let tool = RemindersDeleteTool(service: service)
            let desc = tool.confirmationDescription(parameters: ["search_query": "old task"])
            #expect(desc.contains("old task"))
        }
    }

    // MARK: - RemindersListListsTool

    @Suite("RemindersListListsTool")
    struct RemindersListListsToolTests {
        private let service = RemindersService()

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = RemindersListListsTool(service: service)
            #expect(tool.identifier == "reminders_list_lists")
            #expect(tool.category == .reminders)
            #expect(tool.actionTier == .read)
            #expect(!tool.toolDescription.isEmpty)
        }

        @Test("schema has no required params")
        func schemaNoRequired() {
            let tool = RemindersListListsTool(service: service)
            #expect(tool.parameterSchema.required.isEmpty)
        }
    }

    // MARK: - RemindersProvider

    @Suite("RemindersProvider")
    struct RemindersProviderTests {

        @Test("provider has correct category and tool count")
        func providerMetadata() {
            let provider = RemindersProvider()
            #expect(provider.category == .reminders)
            #expect(provider.displayName == "Reminders")
            #expect(provider.tools.count == 6)
        }

        @Test("provider requires reminders permission")
        func providerPermissions() {
            let provider = RemindersProvider()
            #expect(provider.requiredPermissions == [.reminders])
        }

        @Test("provider contains all expected tool identifiers")
        func providerToolIdentifiers() {
            let provider = RemindersProvider()
            let ids = Set(provider.tools.map(\.identifier))
            #expect(ids.contains("reminders_create"))
            #expect(ids.contains("reminders_list"))
            #expect(ids.contains("reminders_complete"))
            #expect(ids.contains("reminders_modify"))
            #expect(ids.contains("reminders_delete"))
            #expect(ids.contains("reminders_list_lists"))
        }
    }
}
