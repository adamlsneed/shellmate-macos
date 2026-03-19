import Foundation
import Observation

/// Observable state for the main chat interface.
@Observable
@MainActor
final class ChatState {
    var messages: [ChatMessage] = []
    var isStreaming: Bool = false
    var currentStreamingText: String = ""
    var currentToolCalls: [ToolCallStatus] = []
    var inputText: String = ""
    var error: String?

    /// Add a user message to the conversation.
    func addUserMessage(_ text: String) {
        let message = ChatMessage(role: .user, content: text)
        messages.append(message)
        inputText = ""
    }

    /// Add an assistant message (or update streaming message).
    func addAssistantMessage(_ text: String, toolCalls: [ToolCall] = []) {
        let message = ChatMessage(role: .assistant, content: text, toolCalls: toolCalls)
        messages.append(message)
    }

    /// Clear the current streaming state.
    func clearStreaming() {
        isStreaming = false
        currentStreamingText = ""
        currentToolCalls = []
    }
}

/// Tracks the status of a tool call during streaming.
struct ToolCallStatus: Identifiable, Sendable {
    let id: String
    let toolName: String
    let input: String
    var result: String?
    var isComplete: Bool = false
    var isError: Bool = false
}
