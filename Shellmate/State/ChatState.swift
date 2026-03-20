import Foundation
import Observation
import os

@Observable @MainActor
final class ChatState {
    private static let logger = Logger(subsystem: "com.shellmate.app", category: "chat")
    private static let historyFile = "chat-history.json"

    var messages: [ChatMessage] = []
    var isStreaming: Bool = false
    var currentStreamingText: String = ""
    var currentToolCalls: [ToolCallStatus] = []
    var inputText: String = ""
    var error: String?
    var pendingConfirmation: ConfirmationRequest?

    private let configService: ConfigService

    init(configService: ConfigService = ConfigService()) {
        self.configService = configService
    }

    func addUserMessage(_ text: String) {
        messages.append(ChatMessage(role: .user, content: text))
        inputText = ""
        saveHistory()
    }

    func addAssistantMessage(_ text: String, toolCalls: [ToolCall] = []) {
        messages.append(ChatMessage(role: .assistant, content: text, toolCalls: toolCalls))
        saveHistory()
    }

    func clearStreaming() {
        isStreaming = false
        currentStreamingText = ""
        currentToolCalls = []
    }

    func clearConversation() {
        messages = []
        clearStreaming()
        deleteHistory()
    }

    func saveHistory() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(messages.map { PersistableChatMessage(from: $0) })
            let url = configService.configDirectory.appendingPathComponent(Self.historyFile)
            try data.write(to: url, options: .atomic)
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o600], ofItemAtPath: url.path
            )
        } catch {
            Self.logger.warning("Failed to save chat history: \(error.localizedDescription)")
        }
    }

    @discardableResult
    func restoreHistory() -> Bool {
        let url = configService.configDirectory.appendingPathComponent(Self.historyFile)
        guard FileManager.default.fileExists(atPath: url.path) else { return false }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let persisted = try decoder.decode([PersistableChatMessage].self, from: Data(contentsOf: url))
            messages = persisted.map { $0.toChatMessage() }
            return true
        } catch {
            Self.logger.warning("Failed to restore chat history: \(error.localizedDescription)")
            return false
        }
    }

    func deleteHistory() {
        let url = configService.configDirectory.appendingPathComponent(Self.historyFile)
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            Self.logger.info("No chat history to delete: \(error.localizedDescription)")
        }
    }
}

struct ToolCallStatus: Identifiable, Sendable {
    let id: String
    let toolName: String
    let input: String
    var result: String?
    var isComplete: Bool = false
    var isError: Bool = false
}

struct PersistableChatMessage: Codable, Sendable {
    let id: String
    let role: MessageRole
    var content: String
    var toolCalls: [ToolCall]
    var toolResults: [ToolResult]
    let timestamp: Date

    init(from message: ChatMessage) {
        self.id = message.id
        self.role = message.role
        self.content = message.content
        self.toolCalls = message.toolCalls
        self.toolResults = message.toolResults
        self.timestamp = message.timestamp
    }

    func toChatMessage() -> ChatMessage {
        ChatMessage(
            id: id,
            role: role,
            content: content,
            toolCalls: toolCalls,
            toolResults: toolResults,
            timestamp: timestamp
        )
    }
}

// MARK: - ConfirmationRequest

struct ConfirmationRequest: Identifiable, Sendable {
    let id: UUID
    let toolIdentifier: String
    let description: String
    let tier: ActionTier
    let continuation: OneShotContinuation
}
