import Foundation

/// Reads an email message from Mail.app via AppleScript.
struct EmailReadTool: AgentTool {
    let identifier = "email_read"
    let toolDescription = "Read an email message from Mail.app by subject. Returns sender, date, and body."
    let category = ToolCategory.email
    let actionTier = ActionTier.read
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "subject": ToolProperty(
                type: "string",
                description: "The subject line to search for (partial match)."
            ),
            "mailbox": ToolProperty(
                type: "string",
                description: "The mailbox to search in (e.g., 'INBOX'). Defaults to Inbox."
            ),
        ],
        required: ["subject"]
    )

    private let appleScriptService: AppleScriptService
    init(appleScriptService: AppleScriptService) { self.appleScriptService = appleScriptService }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        guard let subject = parameters["subject"] as? String else {
            return .error("Missing required parameter: subject")
        }

        let safeSubject = AppleScriptService.sanitize(subject)
        let mailbox = parameters["mailbox"] as? String ?? "INBOX"
        let safeMailbox = AppleScriptService.sanitize(mailbox)

        let script = """
        tell application "Mail"
            set matchedMessages to {}
            repeat with acct in accounts
                try
                    set mb to mailbox "\(safeMailbox)" of acct
                    set msgs to (messages of mb whose subject contains "\(safeSubject)")
                    if (count of msgs) > 0 then
                        set msg to item 1 of msgs
                        set msgSubject to subject of msg
                        set msgSender to sender of msg
                        set msgDate to date received of msg as string
                        set msgContent to content of msg
                        if (length of msgContent) > 2000 then
                            set msgContent to text 1 thru 2000 of msgContent & "... [truncated]"
                        end if
                        return "Subject: " & msgSubject & linefeed & "From: " & msgSender & linefeed & "Date: " & msgDate & linefeed & linefeed & msgContent
                    end if
                end try
            end repeat
            return "No email found with subject containing: \(safeSubject)"
        end tell
        """

        do {
            let result = try await appleScriptService.execute(script: script, timeout: 30)
            return .success(result)
        } catch {
            return .error("Failed to read email: \(error.localizedDescription)")
        }
    }
}
