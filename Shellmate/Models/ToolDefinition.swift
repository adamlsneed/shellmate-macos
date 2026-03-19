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

// MARK: - Format Conversion

extension Array where Element == ToolDefinition {
    /// Convert tool definitions to Anthropic API format.
    func toAnthropicFormat() -> [[String: Any]] {
        map { tool in
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
    func toOpenAIFormat() -> [[String: Any]] {
        map { tool in
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
