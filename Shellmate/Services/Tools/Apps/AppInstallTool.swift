import Foundation

/// Installs an application or package via Homebrew.
struct AppInstallTool: AgentTool {
    let identifier = "app_install"
    let toolDescription = "Install an application or package via Homebrew. Use cask mode for GUI apps, formula mode for CLI tools."
    let category = ToolCategory.apps
    let actionTier = ActionTier.write
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "name": ToolProperty(type: "string", description: "Name of the package or cask to install"),
            "cask": ToolProperty(type: "boolean", description: "If true, install as a cask (GUI app). Defaults to false."),
        ],
        required: ["name"]
    )

    private let shellService: ShellService
    init(shellService: ShellService) { self.shellService = shellService }

    func confirmationDescription(parameters: [String: Any]) -> String {
        let name = parameters["name"] as? String ?? "unknown"
        let isCask = parameters["cask"] as? Bool ?? false
        return "Install \(isCask ? "app" : "package") '\(name)' via Homebrew"
    }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        guard let name = parameters["name"] as? String, !name.isEmpty else {
            return .error("Missing required parameter: name")
        }

        guard await shellService.which("brew") != nil else {
            return .error("Homebrew is not installed. Install it from https://brew.sh")
        }

        let isCask = parameters["cask"] as? Bool ?? false
        var args = ["install"]
        if isCask { args.append("--cask") }
        args.append(name)

        let result = try await shellService.run(executable: "brew", arguments: args, timeout: 600)
        if result.succeeded {
            return .success("Successfully installed '\(name)'.\n\(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines))")
        }
        return .error("Installation failed: \(result.stderr)")
    }
}
