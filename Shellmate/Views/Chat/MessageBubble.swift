import SwiftUI

/// Renders a single chat message with role-based styling.
struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .top) {
            if message.role == .user { Spacer(minLength: 60) }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 8) {
                // Message text
                if !message.content.isEmpty {
                    Text(MarkdownRenderer.render(message.content))
                        .textSelection(.enabled)
                        .foregroundStyle(ShellmateColors.textPrimary)
                        .padding(12)
                        .background(
                            message.role == .user
                                ? ShellmateColors.shell600.opacity(0.3)
                                : ShellmateColors.navy800
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Tool calls
                ForEach(message.toolCalls) { toolCall in
                    ToolCallDisplay(toolCall: toolCall, result: message.toolResults.first { $0.id == toolCall.id })
                }
            }

            if message.role == .assistant { Spacer(minLength: 60) }
        }
    }
}
