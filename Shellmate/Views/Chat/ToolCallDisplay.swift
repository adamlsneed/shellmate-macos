import SwiftUI
struct ToolCallDisplay: View {
    let toolCall: ToolCall; let result: ToolResult?; @State private var isExpanded = false
    private var inProgress: Bool { result == nil }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() } }) {
                HStack(spacing: 8) {
                    if inProgress { LoadingSpinner().frame(width: 14, height: 14) } else if let r = result, r.isError { Image(systemName: "exclamationmark.circle.fill").font(.caption).foregroundStyle(ShellmateColors.error) } else { Image(systemName: "checkmark.circle.fill").font(.caption).foregroundStyle(ShellmateColors.success) }
                    Image(systemName: FriendlyToolStatus.icon(for: toolCall.name)).font(.caption).foregroundStyle(ShellmateColors.shell400)
                    Text(FriendlyToolStatus.describe(toolCall)).font(.caption).foregroundStyle(ShellmateColors.shell400).lineLimit(1); Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down").font(.caption2).foregroundStyle(ShellmateColors.textMuted)
                }.padding(10).contentShape(Rectangle())
            }.buttonStyle(.plain)
            if isExpanded { Divider().background(ShellmateColors.navy700)
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) { Text("Input:").font(.caption.bold()).foregroundStyle(ShellmateColors.textMuted); ScrollView(.horizontal, showsIndicators: false) { Text(fmtInput(toolCall.input)).font(.system(.caption, design: .monospaced)).foregroundStyle(ShellmateColors.textSecondary).textSelection(.enabled) } }
                    if let r = result { VStack(alignment: .leading, spacing: 4) { Text(r.isError ? "Error:" : "Result:").font(.caption.bold()).foregroundStyle(r.isError ? ShellmateColors.error : ShellmateColors.textMuted); ScrollView { Text(String(r.content.prefix(2000))).font(.system(.caption, design: .monospaced)).foregroundStyle(r.isError ? ShellmateColors.error : ShellmateColors.textSecondary).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }.frame(maxHeight: 200) } }
                    else { HStack(spacing: 8) { BouncingDots(); Text("Executing...").font(.caption).foregroundStyle(ShellmateColors.textMuted) } }
                }.padding(10)
            }
        }.background(ShellmateColors.navy850).clipShape(RoundedRectangle(cornerRadius: 8)).overlay(RoundedRectangle(cornerRadius: 8).stroke(inProgress ? ShellmateColors.shell500.opacity(0.3) : .clear, lineWidth: 1))
    }
    private func fmtInput(_ i: [String: JSONValue]) -> String { guard let d = try? JSONEncoder().encode(i), let j = try? JSONSerialization.jsonObject(with: d), let p = try? JSONSerialization.data(withJSONObject: j, options: .prettyPrinted) else { return "{}" }; return String(data: p, encoding: .utf8) ?? "{}" }
}
enum FriendlyToolStatus {
    static func describe(_ tc: ToolCall) -> String { switch tc.name { case "shell_exec": "Running: \((tc.input["command"]?.stringValue ?? "cmd").prefix(60))"; case "file_read": "Reading \(URL(fileURLWithPath: tc.input["path"]?.stringValue ?? "f").lastPathComponent)"; case "file_write": "Writing \(URL(fileURLWithPath: tc.input["path"]?.stringValue ?? "f").lastPathComponent)"; case "file_list": "Listing \(URL(fileURLWithPath: tc.input["path"]?.stringValue ?? "d").lastPathComponent)"; case "web_search": "Searching: \((tc.input["query"]?.stringValue ?? "q").prefix(50))"; case "web_fetch": "Fetching \((tc.input["url"]?.stringValue ?? "u").prefix(50))"; default: tc.name } }
    static func icon(for n: String) -> String { switch n { case "shell_exec": "terminal.fill"; case "file_read": "doc.text.fill"; case "file_write": "doc.badge.plus"; case "file_list": "folder.fill"; case "web_search": "magnifyingglass"; case "web_fetch": "globe"; default: "wrench.fill" } }
}
