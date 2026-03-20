import Foundation

// MARK: - ContactsSearchTool

/// Searches contacts by name.
struct ContactsSearchTool: AgentTool {
    let identifier = "contacts_search"
    let toolDescription = "Search your contacts by name. Returns matching contacts with phone numbers and email addresses."
    let category = ToolCategory.contacts
    let actionTier = ActionTier.read
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "query": ToolProperty(
                type: "string",
                description: "Name to search for (first name, last name, or full name)."
            ),
            "limit": ToolProperty(
                type: "string",
                description: "Maximum number of results to return. Defaults to 20."
            ),
        ],
        required: ["query"]
    )

    private let service: ContactsService

    init(service: ContactsService) {
        self.service = service
    }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        guard let query = parameters["query"] as? String else {
            return .error("Missing required parameter: query")
        }
        let limit = (parameters["limit"] as? String).flatMap(Int.init) ?? 20

        do {
            let contacts = try await service.search(query: query, limit: limit)
            if contacts.isEmpty {
                return .success("No contacts found matching '\(query)'.")
            }
            let lines = contacts.map { formatContact($0) }
            return .success("Found \(contacts.count) contact(s):\n\n" + lines.joined(separator: "\n\n"))
        } catch {
            return .error(error.localizedDescription)
        }
    }

    private func formatContact(_ contact: ContactInfo) -> String {
        var parts: [String] = []
        parts.append("**\(contact.displayName)** (id: \(contact.identifier))")

        if !contact.organizationName.isEmpty {
            parts.append("  Organization: \(contact.organizationName)")
        }
        for phone in contact.phones {
            parts.append("  Phone (\(phone.label)): \(phone.value)")
        }
        for email in contact.emails {
            parts.append("  Email (\(email.label)): \(email.value)")
        }
        return parts.joined(separator: "\n")
    }
}
