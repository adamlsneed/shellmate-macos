import SwiftUI
struct MessageBubble: View {
    let message: ChatMessage
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if message.role == .user { Spacer(minLength: 60) }
            if message.role == .assistant { Image(systemName: "terminal.fill").font(.caption).foregroundStyle(ShellmateColors.shell400).frame(width: 28, height: 28).background(ShellmateColors.shell700.opacity(0.3)).clipShape(Circle()) }
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 8) {
                if !message.content.isEmpty {
                    if message.content.contains("```") { codeContent(message.content) }
                    else { Text(MarkdownRenderer.render(message.content)).textSelection(.enabled).font(.body).foregroundStyle(ShellmateColors.textPrimary).padding(12).background(bg).clipShape(RoundedRectangle(cornerRadius: 12)) }
                }
                ForEach(message.toolCalls) { tc in ToolCallDisplay(toolCall: tc, result: message.toolResults.first { $0.id == tc.id }) }
            }
            if message.role == .user { Image(systemName: "person.circle.fill").font(.title3).foregroundStyle(ShellmateColors.shell400.opacity(0.6)) }
            if message.role == .assistant { Spacer(minLength: 60) }
        }
    }
    private var bg: Color { message.role == .user ? ShellmateColors.shell600.opacity(0.3) : ShellmateColors.navy800 }
    private func codeContent(_ c: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            let segs = parse(c); ForEach(Array(segs.enumerated()), id: \.offset) { _, s in
                if s.1 { VStack(alignment: .leading, spacing: 0) { if let l = s.2, !l.isEmpty { HStack { Text(l).font(.system(.caption2, design: .monospaced)).foregroundStyle(ShellmateColors.textMuted); Spacer(); Button(action: { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(s.0, forType: .string) }) { Image(systemName: "doc.on.doc").font(.caption2).foregroundStyle(ShellmateColors.textMuted) }.buttonStyle(.plain) }.padding(.horizontal, 12).padding(.vertical, 6).background(ShellmateColors.navy950) }; ScrollView(.horizontal, showsIndicators: false) { Text(s.0).font(.system(.caption, design: .monospaced)).foregroundStyle(ShellmateColors.shell300).textSelection(.enabled).padding(12) }.background(ShellmateColors.navy950) }
                } else if !s.0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { Text(MarkdownRenderer.render(s.0.trimmingCharacters(in: .whitespacesAndNewlines))).textSelection(.enabled).font(.body).foregroundStyle(ShellmateColors.textPrimary).padding(12) }
            }
        }.background(bg).clipShape(RoundedRectangle(cornerRadius: 12))
    }
    private func parse(_ c: String) -> [(String, Bool, String?)] {
        var r: [(String, Bool, String?)] = []; let p = #"```(\w*)\n([\s\S]*?)```"#; guard let re = try? NSRegularExpression(pattern: p) else { return [(c, false, nil)] }; let ns = c as NSString; var last = 0
        for m in re.matches(in: c, range: NSRange(location: 0, length: ns.length)) {
            if m.range.location > last { r.append((ns.substring(with: NSRange(location: last, length: m.range.location - last)), false, nil)) }
            let lang = m.range(at: 1).location != NSNotFound ? ns.substring(with: m.range(at: 1)) : nil
            r.append((ns.substring(with: m.range(at: 2)), true, lang)); last = m.range.location + m.range.length
        }; if last < ns.length { r.append((ns.substring(from: last), false, nil)) }; return r
    }
}
