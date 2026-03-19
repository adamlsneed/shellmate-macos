import Foundation

// MARK: - ToolRegistryError

enum ToolRegistryError: Error, LocalizedError {
    case unknownTool(String)

    var errorDescription: String? {
        switch self {
        case .unknownTool(let name):
            "Unknown tool: \(name)"
        }
    }
}

// MARK: - ToolRegistry

/// Central registry that maps tool identifiers to ``AgentTool`` instances.
///
/// Providers register themselves at launch; the registry indexes every tool
/// by name so lookups during a tool-use loop are O(1).
actor ToolRegistry {
    private var providers: [ToolCategory: ToolProvider] = [:]
    private var toolIndex: [String: AgentTool] = [:]

    // MARK: Registration

    /// Register a provider and index all of its tools.
    func register(_ provider: ToolProvider) {
        providers[provider.category] = provider
        for tool in provider.tools {
            toolIndex[tool.identifier] = tool
        }
    }

    /// Remove a provider and its tools from the registry.
    func unregister(_ category: ToolCategory) {
        guard let provider = providers.removeValue(forKey: category) else { return }
        for tool in provider.tools {
            toolIndex.removeValue(forKey: tool.identifier)
        }
    }

    // MARK: Lookup

    /// Find a tool by its identifier.
    func tool(named identifier: String) -> AgentTool? {
        toolIndex[identifier]
    }

    /// All tools belonging to the given category.
    func tools(in category: ToolCategory) -> [AgentTool] {
        providers[category]?.tools ?? []
    }

    /// Categories that currently have a registered provider.
    func enabledCategories() -> [ToolCategory] {
        Array(providers.keys)
    }

    // MARK: Schema generation

    /// Tool definitions for the given categories, minus any denied tools.
    func toolSchemas(for categories: Set<ToolCategory>, denyCategories: [ToolDenyCategory]) -> [ToolDefinition] {
        let blocked = Set(denyCategories.flatMap(\.blockedTools))
        return categories.flatMap { category -> [ToolDefinition] in
            guard let provider = providers[category] else { return [] }
            return provider.tools
                .filter { !blocked.contains($0.identifier) }
                .map { $0.toToolDefinition() }
        }
    }

    /// Every registered tool definition.
    func allToolSchemas() -> [ToolDefinition] {
        toolIndex.values.map { $0.toToolDefinition() }
    }

    // MARK: Execution

    /// Execute a tool by name, routing to the registered ``AgentTool``.
    func execute(toolName: String, parameters: sending [String: Any]) async throws -> AgentToolResult {
        guard let tool = toolIndex[toolName] else {
            throw ToolRegistryError.unknownTool(toolName)
        }
        let params = parameters // local copy for sending out of actor
        return try await tool.execute(parameters: params)
    }
}
