import SwiftUI

/// Full-screen chat interface with message list and input bar.
/// Placeholder — will be fully built by UI agent.
struct ChatView: View {
    @Environment(AppState.self) private var appState
    @Environment(AIConfigState.self) private var aiConfig
    @State private var chatState = ChatState()

    var body: some View {
        VStack(spacing: 0) {
            // Messages area
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if chatState.messages.isEmpty {
                        emptyState
                    } else {
                        ForEach(chatState.messages) { message in
                            MessageBubble(message: message)
                        }
                    }
                }
                .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()
                .background(ShellmateColors.navy700)

            // Input bar
            inputBar
        }
        .background(ShellmateColors.background)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 48))
                .foregroundStyle(ShellmateColors.shell400.opacity(0.5))
            Text("Start a conversation")
                .font(.title2)
                .foregroundStyle(ShellmateColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 100)
    }

    private var inputBar: some View {
        HStack(spacing: 12) {
            TextField("Message your assistant…", text: $chatState.inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .foregroundStyle(ShellmateColors.textPrimary)
                .padding(12)
                .background(ShellmateColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .lineLimit(1...5)
                .onSubmit {
                    sendMessage()
                }

            Button(action: sendMessage) {
                Image(systemName: chatState.isStreaming ? "stop.circle.fill" : "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(ShellmateColors.accent)
            }
            .buttonStyle(.plain)
            .disabled(chatState.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !chatState.isStreaming)
        }
        .padding(16)
        .background(ShellmateColors.navy900)
    }

    private func sendMessage() {
        let text = chatState.inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        chatState.addUserMessage(text)
        // TODO: Wire up to AI service via ToolUseLoop
    }
}
