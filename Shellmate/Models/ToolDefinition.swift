import Foundation

/// Tool deny categories matching the Electron app's deny map.
enum ToolDenyCategory: String, Codable, Sendable, CaseIterable {
    case exec
    case write
    case read
    case web
    case browser

    /// Tool names blocked by this deny category.
    var blockedTools: [String] {
        switch self {
        case .exec: ["shell_exec"]
        case .write: ["file_write"]
        case .read: ["file_read", "file_list"]
        case .web: ["web_search", "web_fetch"]
        case .browser: ["web_fetch"]
        }
    }
}

/// Schema for a tool exposed to the AI provider.
struct ToolDefinition: Codable, Sendable {
    let name: String
    let description: String
    let inputSchema: ToolInputSchema

    enum CodingKeys: String, CodingKey {
        case name, description
        case inputSchema = "input_schema"
    }
}

struct ToolInputSchema: Codable, Sendable {
    let type: String
    let properties: [String: ToolProperty]
    let required: [String]
}

struct ToolProperty: Codable, Sendable {
    let type: String
    let description: String
    var enumValues: [String]?
    var defaultValue: JSONValue?

    enum CodingKeys: String, CodingKey {
        case type, description
        case enumValues = "enum"
        case defaultValue = "default"
    }
}

/// All available tools and their schemas.
enum ToolDefinitions {
    static let all: [ToolDefinition] = [
        shellExec, fileRead, fileWrite, fileList, webSearch, webFetch,
    ]

    static let shellExec = ToolDefinition(
        name: "shell_exec",
        description: "Execute a shell command on the user's Mac. Use for running terminal commands, installing software, checking system info, etc.",
        inputSchema: ToolInputSchema(
            type: "object",
            properties: [
                "command": ToolProperty(type: "string", description: "The shell command to execute"),
            ],
            required: ["command"]
        )
    )

    static let fileRead = ToolDefinition(
        name: "file_read",
        description: "Read the contents of a file on the user's Mac.",
        inputSchema: ToolInputSchema(
            type: "object",
            properties: [
                "path": ToolProperty(type: "string", description: "Absolute path to the file to read"),
            ],
            required: ["path"]
        )
    )

    static let fileWrite = ToolDefinition(
        name: "file_write",
        description: "Write content to a file on the user's Mac. Creates the file and parent directories if they don't exist.",
        inputSchema: ToolInputSchema(
            type: "object",
            properties: [
                "path": ToolProperty(type: "string", description: "Absolute path to the file to write"),
                "content": ToolProperty(type: "string", description: "Content to write to the file"),
            ],
            required: ["path", "content"]
        )
    )

    static let fileList = ToolDefinition(
        name: "file_list",
        description: "List files and directories at a given path on the user's Mac.",
        inputSchema: ToolInputSchema(
            type: "object",
            properties: [
                "path": ToolProperty(type: "string", description: "Absolute path to the directory to list"),
                "depth": ToolProperty(type: "integer", description: "Maximum depth to recurse (default 2)"),
            ],
            required: ["path"]
        )
    )

    static let webSearch = ToolDefinition(
        name: "web_search",
        description: "Search the web using Brave Search. Returns titles, URLs, and descriptions of results.",
        inputSchema: ToolInputSchema(
            type: "object",
            properties: [
                "query": ToolProperty(type: "string", description: "The search query"),
                "count": ToolProperty(type: "integer", description: "Number of results (default 5, max 20)"),
            ],
            required: ["query"]
        )
    )

    static let webFetch = ToolDefinition(
        name: "web_fetch",
        description: "Fetch the contents of a web page and extract the text.",
        inputSchema: ToolInputSchema(
            type: "object",
            properties: [
                "url": ToolProperty(type: "string", description: "The URL to fetch"),
            ],
            required: ["url"]
        )
    )

    /// Filter tools based on deny list.
    static func available(denyCategories: [ToolDenyCategory]) -> [ToolDefinition] {
        let blocked = Set(denyCategories.flatMap(\.blockedTools))
        return all.filter { !blocked.contains($0.name) }
    }

    /// Convert tool definitions to Anthropic API format.
    static func toAnthropicFormat(_ tools: [ToolDefinition]) -> [[String: Any]] {
        tools.map { tool in
            [
                "name": tool.name,
                "description": tool.description,
                "input_schema": [
                    "type": tool.inputSchema.type,
                    "properties": tool.inputSchema.properties.mapValues { prop in
                        var dict: [String: Any] = ["type": prop.type, "description": prop.description]
                        if let enums = prop.enumValues { dict["enum"] = enums }
                        return dict
                    },
                    "required": tool.inputSchema.required,
                ] as [String: Any],
            ] as [String: Any]
        }
    }

    /// Convert tool definitions to OpenAI function-calling format.
    static func toOpenAIFormat(_ tools: [ToolDefinition]) -> [[String: Any]] {
        tools.map { tool in
            [
                "type": "function",
                "function": [
                    "name": tool.name,
                    "description": tool.description,
                    "parameters": [
                        "type": tool.inputSchema.type,
                        "properties": tool.inputSchema.properties.mapValues { prop in
                            var dict: [String: Any] = ["type": prop.type, "description": prop.description]
                            if let enums = prop.enumValues { dict["enum"] = enums }
                            return dict
                        },
                        "required": tool.inputSchema.required,
                    ] as [String: Any],
                ] as [String: Any],
            ] as [String: Any]
        }
    }
}
