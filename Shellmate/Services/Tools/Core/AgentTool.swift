import Foundation

// MARK: - AgentTool

/// A tool that can be exposed to the AI agent for execution.
protocol AgentTool: Sendable {
    /// Unique identifier used in API tool calls (e.g. "shell_exec").
    var identifier: String { get }

    /// Human-readable description sent to the AI model.
    var toolDescription: String { get }

    /// The capability domain this tool belongs to.
    var category: ToolCategory { get }

    /// How dangerous this tool's action is — drives confirmation UI.
    var actionTier: ActionTier { get }

    /// JSON Schema for the tool's parameters.
    var parameterSchema: ToolInputSchema { get }

    /// Execute the tool with the given parameters.
    func execute(parameters: [String: Any]) async throws -> AgentToolResult

    /// Optional human-readable description for the confirmation dialog.
    func confirmationDescription(parameters: [String: Any]) -> String

    /// Optional async overload — lets a tool look up the actual target of a
    /// search-then-act operation (e.g. resolve which calendar event will be
    /// deleted) and surface it in the prompt. Return `nil` to defer to the
    /// synchronous overload.
    func confirmationDescription(parameters: [String: Any]) async -> String?
}

extension AgentTool {
    func confirmationDescription(parameters: [String: Any]) -> String { "" }
    func confirmationDescription(parameters: [String: Any]) async -> String? { nil }

    /// Convert this tool to a ``ToolDefinition`` suitable for the AI provider API.
    func toToolDefinition() -> ToolDefinition {
        ToolDefinition(
            name: identifier,
            description: toolDescription,
            inputSchema: parameterSchema
        )
    }
}
