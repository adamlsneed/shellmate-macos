import Foundation

/// Uninstalls an application or package via Homebrew.
struct AppUninstallTool: AgentTool {
    let identifier = "app_uninstall"
    let toolDescription = "Uninstall an application or package via Homebrew."
    let category = ToolCategory.apps
    let actionTier = ActionTier.destructive
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "name": ToolProperty(type: "string", description: "Name of the package or cask to uninstall"),
        ],
        required: ["name"]
    )

    private let shellService: ShellService
    init(shellService: ShellService) { self.shellService = shellService }

    func confirmationDescription(parameters: [String: Any]) -> String {
        let name = parameters["name"] as? String ?? "unknown"
        return "Uninstall '\(name)' via Homebrew"
    }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        guard let name = parameters["name"] as? String, !name.isEmpty else {
            return .error("Missing required parameter: name")
        }

        guard await shellService.which("brew") != nil else {
            return .error("Homebrew is not installed. Install it from https://brew.sh")
        }

        let result = try await shellService.run(executable: "brew", arguments: ["uninstall", name], timeout: 120)
        if result.succeeded {
            return .success("Successfully uninstalled '\(name)'.\n\(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines))")
        }
        return .error("Uninstall failed: \(result.stderr)")
    }
}
