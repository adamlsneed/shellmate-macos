import Foundation
import Testing
@testable import Shellmate

@Suite("CalendarProvider Tools")
struct CalendarToolTests {

    private let service = CalendarService()
    private let dateParser = NaturalDateParser()

    // MARK: - CalendarListEventsTool

    @Suite("CalendarListEventsTool")
    struct CalendarListEventsToolTests {
        private let service = CalendarService()

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = CalendarListEventsTool(service: service)
            #expect(tool.identifier == "calendar_list_events")
            #expect(tool.category == .calendar)
            #expect(tool.actionTier == .read)
            #expect(!tool.toolDescription.isEmpty)
        }

        @Test("schema requires start_date and end_date")
        func schemaRequiredParams() {
            let tool = CalendarListEventsTool(service: service)
            #expect(tool.parameterSchema.required.contains("start_date"))
            #expect(tool.parameterSchema.required.contains("end_date"))
        }

        @Test("returns error for missing start_date")
        func missingStartDate() async throws {
            let tool = CalendarListEventsTool(service: service)
            let result = try await tool.execute(parameters: ["end_date": "tomorrow"])
            #expect(result.isError)
            #expect(result.content.contains("start_date"))
        }

        @Test("returns error for missing end_date")
        func missingEndDate() async throws {
            let tool = CalendarListEventsTool(service: service)
            let result = try await tool.execute(parameters: ["start_date": "today"])
            #expect(result.isError)
            #expect(result.content.contains("end_date"))
        }

        @Test("returns error for unparseable date")
        func unparseableDate() async throws {
            let tool = CalendarListEventsTool(service: service)
            let result = try await tool.execute(parameters: [
                "start_date": "xyzzy gibberish",
                "end_date": "tomorrow",
            ])
            #expect(result.isError)
            #expect(result.content.contains("parse"))
        }
    }

    // MARK: - CalendarCreateEventTool

    @Suite("CalendarCreateEventTool")
    struct CalendarCreateEventToolTests {
        private let service = CalendarService()

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = CalendarCreateEventTool(service: service)
            #expect(tool.identifier == "calendar_create_event")
            #expect(tool.category == .calendar)
            #expect(tool.actionTier == .write)
            #expect(!tool.toolDescription.isEmpty)
        }

        @Test("schema requires title and start_date")
        func schemaRequiredParams() {
            let tool = CalendarCreateEventTool(service: service)
            #expect(tool.parameterSchema.required.contains("title"))
            #expect(tool.parameterSchema.required.contains("start_date"))
        }

        @Test("returns error for missing title")
        func missingTitle() async throws {
            let tool = CalendarCreateEventTool(service: service)
            let result = try await tool.execute(parameters: ["start_date": "tomorrow at 2pm"])
            #expect(result.isError)
            #expect(result.content.contains("title"))
        }

        @Test("returns error for missing start_date")
        func missingStartDate() async throws {
            let tool = CalendarCreateEventTool(service: service)
            let result = try await tool.execute(parameters: ["title": "Meeting"])
            #expect(result.isError)
            #expect(result.content.contains("start_date"))
        }

        @Test("provides non-empty confirmation description")
        func confirmationDescription() {
            let tool = CalendarCreateEventTool(service: service)
            let desc = tool.confirmationDescription(parameters: [
                "title": "Team Meeting",
                "start_date": "tomorrow at 3pm",
            ])
            #expect(desc.contains("Team Meeting"))
            #expect(!desc.isEmpty)
        }

        @Test("returns error for unparseable start_date")
        func unparseableStartDate() async throws {
            let tool = CalendarCreateEventTool(service: service)
            let result = try await tool.execute(parameters: [
                "title": "Test",
                "start_date": "not a real date xyz",
            ])
            #expect(result.isError)
            #expect(result.content.contains("parse"))
        }

        @Test("returns error for unparseable duration")
        func unparseableDuration() async throws {
            let tool = CalendarCreateEventTool(service: service)
            let result = try await tool.execute(parameters: [
                "title": "Test",
                "start_date": "tomorrow at 2pm",
                "duration": "invalid duration xyz",
            ])
            #expect(result.isError)
            #expect(result.content.contains("duration"))
        }
    }

    // MARK: - CalendarModifyEventTool

    @Suite("CalendarModifyEventTool")
    struct CalendarModifyEventToolTests {
        private let service = CalendarService()

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = CalendarModifyEventTool(service: service)
            #expect(tool.identifier == "calendar_modify_event")
            #expect(tool.category == .calendar)
            #expect(tool.actionTier == .write)
            #expect(!tool.toolDescription.isEmpty)
        }

        @Test("schema requires search_query")
        func schemaRequiredParams() {
            let tool = CalendarModifyEventTool(service: service)
            #expect(tool.parameterSchema.required.contains("search_query"))
        }

        @Test("returns error for missing search_query")
        func missingSearchQuery() async throws {
            let tool = CalendarModifyEventTool(service: service)
            let result = try await tool.execute(parameters: [:])
            #expect(result.isError)
            #expect(result.content.contains("search_query"))
        }

        @Test("provides non-empty confirmation description")
        func confirmationDescription() {
            let tool = CalendarModifyEventTool(service: service)
            let desc = tool.confirmationDescription(parameters: ["search_query": "Team Meeting"])
            #expect(desc.contains("Team Meeting"))
        }
    }

    // MARK: - CalendarDeleteEventTool

    @Suite("CalendarDeleteEventTool")
    struct CalendarDeleteEventToolTests {
        private let service = CalendarService()

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = CalendarDeleteEventTool(service: service)
            #expect(tool.identifier == "calendar_delete_event")
            #expect(tool.category == .calendar)
            #expect(tool.actionTier == .destructive)
            #expect(!tool.toolDescription.isEmpty)
        }

        @Test("schema requires search_query")
        func schemaRequiredParams() {
            let tool = CalendarDeleteEventTool(service: service)
            #expect(tool.parameterSchema.required.contains("search_query"))
        }

        @Test("returns error for missing search_query")
        func missingSearchQuery() async throws {
            let tool = CalendarDeleteEventTool(service: service)
            let result = try await tool.execute(parameters: [:])
            #expect(result.isError)
            #expect(result.content.contains("search_query"))
        }

        @Test("provides non-empty confirmation description")
        func confirmationDescription() {
            let tool = CalendarDeleteEventTool(service: service)
            let desc = tool.confirmationDescription(parameters: ["search_query": "Old Meeting"])
            #expect(desc.contains("Old Meeting"))
        }
    }

    // MARK: - CalendarCheckAvailabilityTool

    @Suite("CalendarCheckAvailabilityTool")
    struct CalendarCheckAvailabilityToolTests {
        private let service = CalendarService()

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = CalendarCheckAvailabilityTool(service: service)
            #expect(tool.identifier == "calendar_check_availability")
            #expect(tool.category == .calendar)
            #expect(tool.actionTier == .read)
            #expect(!tool.toolDescription.isEmpty)
        }

        @Test("schema requires date")
        func schemaRequiredParams() {
            let tool = CalendarCheckAvailabilityTool(service: service)
            #expect(tool.parameterSchema.required.contains("date"))
        }

        @Test("returns error for missing date")
        func missingDate() async throws {
            let tool = CalendarCheckAvailabilityTool(service: service)
            let result = try await tool.execute(parameters: [:])
            #expect(result.isError)
            #expect(result.content.contains("date"))
        }

        @Test("returns error for unparseable date")
        func unparseableDate() async throws {
            let tool = CalendarCheckAvailabilityTool(service: service)
            let result = try await tool.execute(parameters: ["date": "not a real date xyz"])
            #expect(result.isError)
            #expect(result.content.contains("parse"))
        }
    }

    // MARK: - CalendarProvider

    @Suite("CalendarProvider")
    struct CalendarProviderTests {

        @Test("provider has correct category and tool count")
        func providerMetadata() {
            let provider = CalendarProvider()
            #expect(provider.category == .calendar)
            #expect(provider.displayName == "Calendar")
            #expect(provider.tools.count == 5)
        }

        @Test("provider requires calendars permission")
        func providerPermissions() {
            let provider = CalendarProvider()
            #expect(provider.requiredPermissions == [.calendars])
        }

        @Test("provider contains all expected tool identifiers")
        func providerToolIdentifiers() {
            let provider = CalendarProvider()
            let ids = Set(provider.tools.map(\.identifier))
            #expect(ids.contains("calendar_list_events"))
            #expect(ids.contains("calendar_create_event"))
            #expect(ids.contains("calendar_modify_event"))
            #expect(ids.contains("calendar_delete_event"))
            #expect(ids.contains("calendar_check_availability"))
        }
    }
}
