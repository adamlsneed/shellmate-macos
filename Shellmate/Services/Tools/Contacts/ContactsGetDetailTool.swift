import Contacts
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

    private func formatDetailedContact(_ contact: CNContact) -> String {
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

        if !contact.phoneNumbers.isEmpty {
            parts.append("\nPhone Numbers:")
            for phone in contact.phoneNumbers {
                let label = CNLabeledValue<NSString>.localizedString(forLabel: phone.label ?? "other")
                parts.append("  \(label): \(phone.value.stringValue)")
            }
        }

        if !contact.emailAddresses.isEmpty {
            parts.append("\nEmail Addresses:")
            for email in contact.emailAddresses {
                let label = CNLabeledValue<NSString>.localizedString(forLabel: email.label ?? "other")
                parts.append("  \(label): \(email.value as String)")
            }
        }

        if !contact.postalAddresses.isEmpty {
            parts.append("\nAddresses:")
            for address in contact.postalAddresses {
                let label = CNLabeledValue<NSString>.localizedString(forLabel: address.label ?? "other")
                let formatted = CNPostalAddressFormatter.string(from: address.value, style: .mailingAddress)
                parts.append("  \(label): \(formatted)")
            }
        }

        if !contact.urlAddresses.isEmpty {
            parts.append("\nURLs:")
            for url in contact.urlAddresses {
                let label = CNLabeledValue<NSString>.localizedString(forLabel: url.label ?? "other")
                parts.append("  \(label): \(url.value as String)")
            }
        }

        if let birthday = contact.birthday, let date = Calendar.current.date(from: birthday) {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            parts.append("\nBirthday: \(formatter.string(from: date))")
        }

        if !contact.note.isEmpty {
            parts.append("\nNotes: \(contact.note)")
        }

        return parts.joined(separator: "\n")
    }
}
