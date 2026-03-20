import Foundation
import Testing
@testable import Shellmate

@Suite("ContactsProvider Tools")
struct ContactsToolTests {

    // MARK: - ContactsSearchTool

    @Suite("ContactsSearchTool")
    struct ContactsSearchToolTests {
        private let service = ContactsService()

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = ContactsSearchTool(service: service)
            #expect(tool.identifier == "contacts_search")
            #expect(tool.category == .contacts)
            #expect(tool.actionTier == .read)
            #expect(!tool.toolDescription.isEmpty)
        }

        @Test("schema requires query")
        func schemaRequiredParams() {
            let tool = ContactsSearchTool(service: service)
            #expect(tool.parameterSchema.required.contains("query"))
        }

        @Test("returns error for missing query")
        func missingQuery() async throws {
            let tool = ContactsSearchTool(service: service)
            let result = try await tool.execute(parameters: [:])
            #expect(result.isError)
            #expect(result.content.contains("query"))
        }
    }

    // MARK: - ContactsGetDetailTool

    @Suite("ContactsGetDetailTool")
    struct ContactsGetDetailToolTests {
        private let service = ContactsService()

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = ContactsGetDetailTool(service: service)
            #expect(tool.identifier == "contacts_get_detail")
            #expect(tool.category == .contacts)
            #expect(tool.actionTier == .read)
            #expect(!tool.toolDescription.isEmpty)
        }

        @Test("schema requires contact_id")
        func schemaRequiredParams() {
            let tool = ContactsGetDetailTool(service: service)
            #expect(tool.parameterSchema.required.contains("contact_id"))
        }

        @Test("returns error for missing contact_id")
        func missingContactId() async throws {
            let tool = ContactsGetDetailTool(service: service)
            let result = try await tool.execute(parameters: [:])
            #expect(result.isError)
            #expect(result.content.contains("contact_id"))
        }
    }

    // MARK: - ContactsCreateTool

    @Suite("ContactsCreateTool")
    struct ContactsCreateToolTests {
        private let service = ContactsService()

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = ContactsCreateTool(service: service)
            #expect(tool.identifier == "contacts_create")
            #expect(tool.category == .contacts)
            #expect(tool.actionTier == .write)
            #expect(!tool.toolDescription.isEmpty)
        }

        @Test("schema requires first_name")
        func schemaRequiredParams() {
            let tool = ContactsCreateTool(service: service)
            #expect(tool.parameterSchema.required.contains("first_name"))
        }

        @Test("returns error for missing first_name")
        func missingFirstName() async throws {
            let tool = ContactsCreateTool(service: service)
            let result = try await tool.execute(parameters: [:])
            #expect(result.isError)
            #expect(result.content.contains("first_name"))
        }

        @Test("provides non-empty confirmation description")
        func confirmationDescription() {
            let tool = ContactsCreateTool(service: service)
            let desc = tool.confirmationDescription(parameters: [
                "first_name": "John",
                "last_name": "Doe",
            ])
            #expect(desc.contains("John Doe"))
        }
    }

    // MARK: - ContactsUpdateTool

    @Suite("ContactsUpdateTool")
    struct ContactsUpdateToolTests {
        private let service = ContactsService()

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = ContactsUpdateTool(service: service)
            #expect(tool.identifier == "contacts_update")
            #expect(tool.category == .contacts)
            #expect(tool.actionTier == .write)
            #expect(!tool.toolDescription.isEmpty)
        }

        @Test("schema requires contact_id")
        func schemaRequiredParams() {
            let tool = ContactsUpdateTool(service: service)
            #expect(tool.parameterSchema.required.contains("contact_id"))
        }

        @Test("returns error for missing contact_id")
        func missingContactId() async throws {
            let tool = ContactsUpdateTool(service: service)
            let result = try await tool.execute(parameters: [:])
            #expect(result.isError)
            #expect(result.content.contains("contact_id"))
        }

        @Test("provides non-empty confirmation description")
        func confirmationDescription() {
            let tool = ContactsUpdateTool(service: service)
            let desc = tool.confirmationDescription(parameters: ["contact_id": "ABC123"])
            #expect(desc.contains("ABC123"))
        }
    }

    // MARK: - ContactsProvider

    @Suite("ContactsProvider")
    struct ContactsProviderTests {

        @Test("provider has correct category and tool count")
        func providerMetadata() {
            let provider = ContactsProvider()
            #expect(provider.category == .contacts)
            #expect(provider.displayName == "Contacts")
            #expect(provider.tools.count == 4)
        }

        @Test("provider requires contacts permission")
        func providerPermissions() {
            let provider = ContactsProvider()
            #expect(provider.requiredPermissions == [.contacts])
        }

        @Test("provider contains all expected tool identifiers")
        func providerToolIdentifiers() {
            let provider = ContactsProvider()
            let ids = Set(provider.tools.map(\.identifier))
            #expect(ids.contains("contacts_search"))
            #expect(ids.contains("contacts_get_detail"))
            #expect(ids.contains("contacts_create"))
            #expect(ids.contains("contacts_update"))
        }
    }
}
