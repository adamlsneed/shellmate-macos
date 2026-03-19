import Foundation

/// Role in a conversation
enum MessageRole: String, Codable, Sendable {
    case user
    case assistant
    case system
    case tool
}

/// A single message in the chat conversation.
struct ChatMessage: Identifiable, Sendable {
    let id: String
    let role: MessageRole
    var content: String
    var toolCalls: [ToolCall]
    var toolResults: [ToolResult]
    let timestamp: Date

    init(
        id: String = UUID().uuidString,
        role: MessageRole,
        content: String,
        toolCalls: [ToolCall] = [],
        toolResults: [ToolResult] = [],
        timestamp: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.toolCalls = toolCalls
        self.toolResults = toolResults
        self.timestamp = timestamp
    }
}

/// A tool invocation requested by the AI.
struct ToolCall: Identifiable, Codable, Sendable {
    let id: String
    let name: String
    let input: [String: JSONValue]
}

/// The result of executing a tool.
struct ToolResult: Identifiable, Codable, Sendable {
    let id: String        // matches ToolCall.id
    let content: String
    let isError: Bool
}

/// Type-safe JSON value enum for tool inputs/outputs.
enum JSONValue: Codable, Sendable, Equatable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([JSONValue])
    case object([String: JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let int = try? container.decode(Int.self) {
            self = .int(int)
        } else if let double = try? container.decode(Double.self) {
            self = .double(double)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let array = try? container.decode([JSONValue].self) {
            self = .array(array)
        } else if let dict = try? container.decode([String: JSONValue].self) {
            self = .object(dict)
        } else {
            self = .null
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let s): try container.encode(s)
        case .int(let i): try container.encode(i)
        case .double(let d): try container.encode(d)
        case .bool(let b): try container.encode(b)
        case .array(let a): try container.encode(a)
        case .object(let o): try container.encode(o)
        case .null: try container.encodeNil()
        }
    }

    /// Extract as a plain Any value for interop with JSONSerialization.
    var anyValue: Any {
        switch self {
        case .string(let s): s
        case .int(let i): i
        case .double(let d): d
        case .bool(let b): b
        case .array(let a): a.map(\.anyValue)
        case .object(let o): o.mapValues(\.anyValue)
        case .null: NSNull()
        }
    }

    /// Extract as String if possible.
    var stringValue: String? {
        if case .string(let s) = self { return s }
        return nil
    }

    /// Extract as Int if possible.
    var intValue: Int? {
        if case .int(let i) = self { return i }
        return nil
    }
}
