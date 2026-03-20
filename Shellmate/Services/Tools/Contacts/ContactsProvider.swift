import Foundation

// MARK: - ContactsProvider

/// Provides contact tools to the agent tool registry.
struct ContactsProvider: ToolProvider {
    let category = ToolCategory.contacts
    let displayName = "Contacts"
    let requiredPermissions: [SystemPermission] = [.contacts]

    private let service = ContactsService()

    var tools: [AgentTool] {
        [
            ContactsSearchTool(service: service),
            ContactsGetDetailTool(service: service),
            ContactsCreateTool(service: service),
            ContactsUpdateTool(service: service),
        ]
    }
}
