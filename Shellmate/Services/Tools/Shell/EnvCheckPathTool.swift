import Foundation

// MARK: - EnvCheckPathTool

/// Checks whether a command-line tool is installed and returns its path.
struct EnvCheckPathTool: AgentTool {
    let identifier = "env_check_path"
    let toolDescription = "Check if a command-line tool is installed and return its path."
    let category = ToolCategory.shell
    let actionTier = ActionTier.read
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "command": ToolProperty(type: "string", description: "The command name to look up (e.g. 'git', 'python3', 'node')"),
        ],
        required: ["command"]
    )

    private let shellService: ShellService
    init(service: ShellService) { self.shellService = service }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        guard let command = parameters["command"] as? String else {
            return .error("Missing required 'command' parameter")
        }

        if let path = await shellService.which(command) {
            return .success("\(command) is installed at: \(path.path)")
        } else {
            return .success("\(command) is not installed.")
        }
    }
}
