import SwiftUI

/// Expandable display of a tool call and its result.
struct ToolCallDisplay: View {
    let toolCall: ToolCall
    let result: ToolResult?
    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 8) {
                // Input
                Text("Input:")
                    .font(.caption.bold())
                    .foregroundStyle(ShellmateColors.textMuted)
                Text(formatInput(toolCall.input))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(ShellmateColors.textSecondary)
                    .textSelection(.enabled)

                // Result
                if let result {
                    Text(result.isError ? "Error:" : "Result:")
                        .font(.caption.bold())
                        .foregroundStyle(result.isError ? ShellmateColors.error : ShellmateColors.textMuted)
                    Text(result.content.prefix(2000))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(result.isError ? ShellmateColors.error : ShellmateColors.textSecondary)
                        .textSelection(.enabled)
                }
            }
            .padding(8)
        } label: {
            Label(
                FriendlyToolStatus.describe(toolCall),
                systemImage: FriendlyToolStatus.icon(for: toolCall.name)
            )
            .font(.caption)
            .foregroundStyle(ShellmateColors.shell400)
        }
        .padding(8)
        .background(ShellmateColors.navy850)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func formatInput(_ input: [String: JSONValue]) -> String {
        guard let data = try? JSONEncoder().encode(input),
              let json = try? JSONSerialization.jsonObject(with: data),
              let pretty = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted) else {
            return "{}"
        }
        return String(data: pretty, encoding: .utf8) ?? "{}"
    }
}

/// Human-readable descriptions for tool calls.
enum FriendlyToolStatus {
    static func describe(_ toolCall: ToolCall) -> String {
        switch toolCall.name {
        case "shell_exec":
            let cmd = toolCall.input["command"]?.stringValue ?? "command"
            return "Running: \(cmd.prefix(60))"
        case "file_read":
            let path = toolCall.input["path"]?.stringValue ?? "file"
            return "Reading \(URL(fileURLWithPath: path).lastPathComponent)"
        case "file_write":
            let path = toolCall.input["path"]?.stringValue ?? "file"
            return "Writing \(URL(fileURLWithPath: path).lastPathComponent)"
        case "file_list":
            let path = toolCall.input["path"]?.stringValue ?? "directory"
            return "Listing \(URL(fileURLWithPath: path).lastPathComponent)"
        case "web_search":
            let query = toolCall.input["query"]?.stringValue ?? "query"
            return "Searching: \(query.prefix(50))"
        case "web_fetch":
            let url = toolCall.input["url"]?.stringValue ?? "page"
            return "Fetching \(url.prefix(50))"
        default:
            return toolCall.name
        }
    }

    static func icon(for toolName: String) -> String {
        switch toolName {
        case "shell_exec": "terminal.fill"
        case "file_read": "doc.text.fill"
        case "file_write": "doc.badge.plus"
        case "file_list": "folder.fill"
        case "web_search": "magnifyingglass"
        case "web_fetch": "globe"
        default: "wrench.fill"
        }
    }
}
