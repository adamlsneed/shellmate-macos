import Contacts
import Foundation

// MARK: - ContactsServiceError

enum ContactsServiceError: Error, LocalizedError {
    case accessDenied
    case contactNotFound(String)
    case saveFailed(String)
    case fetchFailed(String)

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            "Contacts access is not granted. Please allow contacts access in System Settings."
        case .contactNotFound(let query):
            "No contact found matching '\(query)'."
        case .saveFailed(let reason):
            "Failed to save contact: \(reason)"
        case .fetchFailed(let reason):
            "Failed to fetch contacts: \(reason)"
        }
    }
}

// MARK: - ContactsService

/// Actor wrapping CNContactStore for thread-safe contact operations.
actor ContactsService {
    private let store = CNContactStore()

    /// Keys to fetch for search results (summary info).
    private static let searchKeys: [CNKeyDescriptor] = [
        CNContactIdentifierKey as CNKeyDescriptor,
        CNContactGivenNameKey as CNKeyDescriptor,
        CNContactFamilyNameKey as CNKeyDescriptor,
        CNContactOrganizationNameKey as CNKeyDescriptor,
        CNContactPhoneNumbersKey as CNKeyDescriptor,
        CNContactEmailAddressesKey as CNKeyDescriptor,
    ]

    /// Keys to fetch for detailed info.
    private static let detailKeys: [CNKeyDescriptor] = [
        CNContactIdentifierKey as CNKeyDescriptor,
        CNContactGivenNameKey as CNKeyDescriptor,
        CNContactFamilyNameKey as CNKeyDescriptor,
        CNContactMiddleNameKey as CNKeyDescriptor,
        CNContactOrganizationNameKey as CNKeyDescriptor,
        CNContactJobTitleKey as CNKeyDescriptor,
        CNContactPhoneNumbersKey as CNKeyDescriptor,
        CNContactEmailAddressesKey as CNKeyDescriptor,
        CNContactPostalAddressesKey as CNKeyDescriptor,
        CNContactUrlAddressesKey as CNKeyDescriptor,
        CNContactBirthdayKey as CNKeyDescriptor,
        CNContactNoteKey as CNKeyDescriptor,
    ]

    /// Ensures we have access to contacts, requesting if needed.
    func ensureAccess() async throws {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        if status == .notDetermined {
            try await store.requestAccess(for: .contacts)
        }
        let updated = CNContactStore.authorizationStatus(for: .contacts)
        guard updated == .authorized else {
            throw ContactsServiceError.accessDenied
        }
    }

    /// Searches contacts by name.
    func search(query: String, limit: Int = 20) async throws -> [CNContact] {
        try await ensureAccess()
        let predicate = CNContact.predicateForContacts(matchingName: query)
        do {
            let results = try store.unifiedContacts(matching: predicate, keysToFetch: Self.searchKeys)
            return Array(results.prefix(limit))
        } catch {
            throw ContactsServiceError.fetchFailed(error.localizedDescription)
        }
    }

    /// Gets detailed info for a contact by identifier.
    func getDetail(identifier: String) async throws -> CNContact {
        try await ensureAccess()
        do {
            return try store.unifiedContact(withIdentifier: identifier, keysToFetch: Self.detailKeys)
        } catch {
            throw ContactsServiceError.contactNotFound(identifier)
        }
    }

    /// Creates a new contact.
    func create(
        firstName: String,
        lastName: String?,
        phones: [(label: String, number: String)]?,
        emails: [(label: String, address: String)]?,
        organization: String?
    ) async throws -> CNContact {
        try await ensureAccess()
        let contact = CNMutableContact()
        contact.givenName = firstName
        if let last = lastName { contact.familyName = last }
        if let org = organization { contact.organizationName = org }

        if let phones {
            contact.phoneNumbers = phones.map {
                CNLabeledValue(label: mapLabel($0.label), value: CNPhoneNumber(stringValue: $0.number))
            }
        }
        if let emails {
            contact.emailAddresses = emails.map {
                CNLabeledValue(label: mapLabel($0.label), value: $0.address as NSString)
            }
        }

        let saveRequest = CNSaveRequest()
        saveRequest.add(contact, toContainerWithIdentifier: nil)
        do {
            try store.execute(saveRequest)
        } catch {
            throw ContactsServiceError.saveFailed(error.localizedDescription)
        }
        return contact
    }

    /// Updates an existing contact.
    func update(
        identifier: String,
        newFirstName: String?,
        newLastName: String?,
        newOrganization: String?,
        newPhones: [(label: String, number: String)]?,
        newEmails: [(label: String, address: String)]?
    ) async throws -> CNContact {
        try await ensureAccess()
        let contact: CNContact
        do {
            contact = try store.unifiedContact(withIdentifier: identifier, keysToFetch: Self.detailKeys)
        } catch {
            throw ContactsServiceError.contactNotFound(identifier)
        }

        guard let mutable = contact.mutableCopy() as? CNMutableContact else {
            throw ContactsServiceError.saveFailed("Could not create mutable copy.")
        }

        if let first = newFirstName { mutable.givenName = first }
        if let last = newLastName { mutable.familyName = last }
        if let org = newOrganization { mutable.organizationName = org }
        if let phones = newPhones {
            mutable.phoneNumbers = phones.map {
                CNLabeledValue(label: mapLabel($0.label), value: CNPhoneNumber(stringValue: $0.number))
            }
        }
        if let emails = newEmails {
            mutable.emailAddresses = emails.map {
                CNLabeledValue(label: mapLabel($0.label), value: $0.address as NSString)
            }
        }

        let saveRequest = CNSaveRequest()
        saveRequest.update(mutable)
        do {
            try store.execute(saveRequest)
        } catch {
            throw ContactsServiceError.saveFailed(error.localizedDescription)
        }
        return mutable
    }

    // MARK: - Private

    private func mapLabel(_ label: String) -> String {
        switch label.lowercased() {
        case "home": CNLabelHome
        case "work": CNLabelWork
        case "mobile", "cell": CNLabelPhoneNumberMobile
        case "main": CNLabelPhoneNumberMain
        case "iphone": CNLabelPhoneNumberiPhone
        default: label
        }
    }
}
