import Foundation

/// Opens a compose window in Mail.app. NEVER auto-sends.
struct EmailComposeTool: AgentTool {
    let identifier = "email_compose"
    let toolDescription = "Open a new email compose window in Mail.app with pre-filled fields. The email is NOT sent automatically — the user must review and click Send."
    let category = ToolCategory.email
    let actionTier = ActionTier.write
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "to": ToolProperty(
                type: "string",
                description: "The recipient email address."
            ),
            "subject": ToolProperty(
                type: "string",
                description: "The email subject line."
            ),
            "body": ToolProperty(
                type: "string",
                description: "The email body text."
            ),
            "cc": ToolProperty(
                type: "string",
                description: "CC recipient email address (optional)."
            ),
        ],
        required: ["to", "subject", "body"]
    )

    private let appleScriptService: AppleScriptService
    init(appleScriptService: AppleScriptService) { self.appleScriptService = appleScriptService }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        guard let to = parameters["to"] as? String else {
            return .error("Missing required parameter: to")
        }
        guard let subject = parameters["subject"] as? String else {
            return .error("Missing required parameter: subject")
        }
        guard let body = parameters["body"] as? String else {
            return .error("Missing required parameter: body")
        }

        let safeTo = AppleScriptService.sanitize(to)
        let safeSubject = AppleScriptService.sanitize(subject)
        let safeBody = AppleScriptService.sanitize(body)

        var ccPart = ""
        if let cc = parameters["cc"] as? String, !cc.isEmpty {
            let safeCc = AppleScriptService.sanitize(cc)
            ccPart = """

                        make new to recipient at end of cc recipients with properties {address:"\(safeCc)"}
            """
        }

        // CRITICAL: We create a visible outgoing message but do NOT send it.
        // The user must click Send manually.
        let script = """
        tell application "Mail"
            set newMsg to make new outgoing message with properties {subject:"\(safeSubject)", content:"\(safeBody)", visible:true}
            tell newMsg
                make new to recipient at end of to recipients with properties {address:"\(safeTo)"}\(ccPart)
            end tell
            activate
            return "Compose window opened for: \(safeTo)"
        end tell
        """

        do {
            let result = try await appleScriptService.execute(script: script, timeout: 15)
            return .success(result + "\nNote: The email has NOT been sent. Please review and click Send manually.")
        } catch {
            return .error("Failed to open compose window: \(error.localizedDescription)")
        }
    }

    func confirmationDescription(parameters: [String: Any]) -> String {
        let to = parameters["to"] as? String ?? "unknown"
        let subject = parameters["subject"] as? String ?? ""
        return "Open email compose to \(to): \(subject)"
    }
}
