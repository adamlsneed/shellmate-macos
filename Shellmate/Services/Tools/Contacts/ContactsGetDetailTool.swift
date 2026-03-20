import Foundation

// MARK: - ContactsGetDetailTool

/// Gets detailed information for a specific contact by identifier.
struct ContactsGetDetailTool: AgentTool {
    let identifier = "contacts_get_detail"
    let toolDescription = "Get detailed information for a specific contact by their identifier. Use contacts_search first to find the identifier."
    let category = ToolCategory.contacts
    let actionTier = ActionTier.read
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "contact_id": ToolProperty(
                type: "string",
                description: "The contact identifier (obtained from contacts_search results)."
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

        do {
            let contact = try await service.getDetail(identifier: contactId)
            return .success(formatDetailedContact(contact))
        } catch {
            return .error(error.localizedDescription)
        }
    }

    private func formatDetailedContact(_ contact: ContactInfo) -> String {
        var parts: [String] = []
        let name = [contact.givenName, contact.middleName, contact.familyName]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        parts.append("Name: \(name.isEmpty ? "No Name" : name)")

        if !contact.organizationName.isEmpty {
            parts.append("Organization: \(contact.organizationName)")
        }
        if !contact.jobTitle.isEmpty {
            parts.append("Job Title: \(contact.jobTitle)")
        }

        if !contact.phones.isEmpty {
            parts.append("\nPhone Numbers:")
            for phone in contact.phones {
                parts.append("  \(phone.label): \(phone.value)")
            }
        }

        if !contact.emails.isEmpty {
            parts.append("\nEmail Addresses:")
            for email in contact.emails {
                parts.append("  \(email.label): \(email.value)")
            }
        }

        if !contact.addresses.isEmpty {
            parts.append("\nAddresses:")
            for address in contact.addresses {
                parts.append("  \(address.label): \(address.value)")
            }
        }

        if !contact.urls.isEmpty {
            parts.append("\nURLs:")
            for url in contact.urls {
                parts.append("  \(url.label): \(url.value)")
            }
        }

        if let birthday = contact.birthday {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            parts.append("\nBirthday: \(formatter.string(from: birthday))")
        }

        if !contact.note.isEmpty {
            parts.append("\nNotes: \(contact.note)")
        }

        return parts.joined(separator: "\n")
    }
}
