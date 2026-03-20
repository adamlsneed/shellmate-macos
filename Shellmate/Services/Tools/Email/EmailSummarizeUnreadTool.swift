import Foundation

/// Summarizes unread emails from Mail.app via AppleScript.
struct EmailSummarizeUnreadTool: AgentTool {
    let identifier = "email_summarize_unread"
    let toolDescription = "Get a count and summary of unread emails from Mail.app, including subjects and senders."
    let category = ToolCategory.email
    let actionTier = ActionTier.read
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "limit": ToolProperty(
                type: "integer",
                description: "Maximum number of unread emails to list. Defaults to 10."
            ),
        ],
        required: []
    )

    private let appleScriptService: AppleScriptService
    init(appleScriptService: AppleScriptService) { self.appleScriptService = appleScriptService }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        let limit: Int
        if let l = parameters["limit"] as? Int {
            limit = min(max(l, 1), 50)
        } else if let l = parameters["limit"] as? Double {
            limit = min(max(Int(l), 1), 50)
        } else {
            limit = 10
        }

        let script = """
        tell application "Mail"
            set unreadCount to unread count of inbox
            set output to "Unread count: " & unreadCount & linefeed & linefeed
            if unreadCount > 0 then
                set msgs to (messages of inbox whose read status is false)
                set maxMsgs to \(limit)
                if (count of msgs) < maxMsgs then set maxMsgs to count of msgs
                repeat with i from 1 to maxMsgs
                    set msg to item i of msgs
                    set output to output & "• " & subject of msg & " — from " & sender of msg & linefeed
                end repeat
                if unreadCount > \(limit) then
                    set output to output & linefeed & "... and " & (unreadCount - \(limit)) & " more unread emails."
                end if
            end if
            return output
        end tell
        """

        do {
            let result = try await appleScriptService.execute(script: script, timeout: 30)
            return .success(result)
        } catch {
            return .error("Failed to summarize unread emails: \(error.localizedDescription)")
        }
    }
}
