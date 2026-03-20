// MARK: - AgentToolResult

/// The result of executing an agent tool, distinct from the chat-layer `ToolResult`.
struct AgentToolResult: Sendable {
    let content: String
    let isError: Bool
    let metadata: [String: String]

    static func success(_ content: String, metadata: [String: String] = [:]) -> AgentToolResult {
        AgentToolResult(content: content, isError: false, metadata: metadata)
    }

    static func error(_ content: String, metadata: [String: String] = [:]) -> AgentToolResult {
        AgentToolResult(content: content, isError: true, metadata: metadata)
    }
}

// MARK: - ActionTier

/// Classifies a tool action by how dangerous it is.
enum ActionTier: String, Sendable {
    case read
    case write
    case destructive
}
