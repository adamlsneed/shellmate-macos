import Foundation

// MARK: - ContactsUpdateTool

/// Updates an existing contact.
struct ContactsUpdateTool: AgentTool {
    let identifier = "contacts_update"
    let toolDescription = "Update an existing contact. Use contacts_search first to find the contact identifier."
    let category = ToolCategory.contacts
    let actionTier = ActionTier.write
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "contact_id": ToolProperty(
                type: "string",
                description: "The contact identifier (obtained from contacts_search results)."
            ),
            "new_first_name": ToolProperty(
                type: "string",
                description: "New first name."
            ),
            "new_last_name": ToolProperty(
                type: "string",
                description: "New last name."
            ),
            "new_phone": ToolProperty(
                type: "string",
                description: "New phone numbers (replaces existing). Format: 'mobile:555-1234;work:555-5678'."
            ),
            "new_email": ToolProperty(
                type: "string",
                description: "New email addresses (replaces existing). Format: 'home:john@example.com;work:john@corp.com'."
            ),
            "new_organization": ToolProperty(
                type: "string",
                description: "New organization name."
            ),
        ],
        required: ["contact_id"]
    )

    private let service: ContactsService

    init(service: ContactsService) {
        self.service = service
    }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        guard let contactId = parameters["contact_id"] as? String else {
            return .error("Missing required parameter: contact_id")
        }

        let newFirstName = parameters["new_first_name"] as? String
        let newLastName = parameters["new_last_name"] as? String
        let newOrganization = parameters["new_organization"] as? String
        let newPhones = (parameters["new_phone"] as? String).map { parseLabeledValues($0) }
        let newEmails = (parameters["new_email"] as? String).map { parseLabeledValues($0) }

        do {
            let contact = try await service.update(
                identifier: contactId,
                newFirstName: newFirstName,
                newLastName: newLastName,
                newOrganization: newOrganization,
                newPhones: newPhones?.map { (label: $0.0, number: $0.1) },
                newEmails: newEmails?.map { (label: $0.0, address: $0.1) }
            )
            return .success("Updated contact '\(contact.displayName)'.")
        } catch {
            return .error(error.localizedDescription)
        }
    }

    func confirmationDescription(parameters: [String: Any]) -> String {
        let id = parameters["contact_id"] as? String ?? "contact"
        return "Update contact '\(id)'"
    }

    /// Parses "label:value;label:value" or just "value" format.
    private func parseLabeledValues(_ text: String) -> [(String, String)] {
        text.components(separatedBy: ";").compactMap { entry in
            let trimmed = entry.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { return nil }
            let parts = trimmed.components(separatedBy: ":")
            if parts.count >= 2 {
                let label = parts[0].trimmingCharacters(in: .whitespaces)
                let value = parts.dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces)
                return (label, value)
            }
            return ("other", trimmed)
        }
    }
}
