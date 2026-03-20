import Contacts
import Foundation

// MARK: - ContactsCreateTool

/// Creates a new contact.
struct ContactsCreateTool: AgentTool {
    let identifier = "contacts_create"
    let toolDescription = "Create a new contact with name, phone numbers, email addresses, and organization."
    let category = ToolCategory.contacts
    let actionTier = ActionTier.write
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "first_name": ToolProperty(
                type: "string",
                description: "First name of the contact."
            ),
            "last_name": ToolProperty(
                type: "string",
                description: "Last name of the contact."
            ),
            "phone": ToolProperty(
                type: "string",
                description: "Phone number. For multiple, use semicolons: 'mobile:555-1234;work:555-5678'."
            ),
            "email": ToolProperty(
                type: "string",
                description: "Email address. For multiple, use semicolons: 'home:john@example.com;work:john@corp.com'."
            ),
            "organization": ToolProperty(
                type: "string",
                description: "Organization or company name."
            ),
        ],
        required: ["first_name"]
    )

    private let service: ContactsService

    init(service: ContactsService) {
        self.service = service
    }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        guard let firstName = parameters["first_name"] as? String else {
            return .error("Missing required parameter: first_name")
        }

        let lastName = parameters["last_name"] as? String
        let organization = parameters["organization"] as? String
        let phones = (parameters["phone"] as? String).map { parseLabeledValues($0) }
        let emails = (parameters["email"] as? String).map { parseLabeledValues($0) }

        do {
            let contact = try await service.create(
                firstName: firstName,
                lastName: lastName,
                phones: phones?.map { (label: $0.0, number: $0.1) },
                emails: emails?.map { (label: $0.0, address: $0.1) },
                organization: organization
            )
            let name = [contact.givenName, contact.familyName].filter { !$0.isEmpty }.joined(separator: " ")
            return .success("Created contact '\(name)'.")
        } catch {
            return .error(error.localizedDescription)
        }
    }

    func confirmationDescription(parameters: [String: Any]) -> String {
        let first = parameters["first_name"] as? String ?? ""
        let last = parameters["last_name"] as? String ?? ""
        let name = [first, last].filter { !$0.isEmpty }.joined(separator: " ")
        return "Create contact '\(name)'"
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
