import Foundation

/// Updates an installed application or package via Homebrew.
struct AppUpdateTool: AgentTool {
    let identifier = "app_update"
    let toolDescription = "Update (upgrade) an installed application or package via Homebrew. If no name given, upgrades all outdated packages."
    let category = ToolCategory.apps
    let actionTier = ActionTier.write
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "name": ToolProperty(type: "string", description: "Name of the package to upgrade. Omit to upgrade all outdated packages."),
        ],
        required: []
    )

    private let shellService: ShellService
    init(shellService: ShellService) { self.shellService = shellService }

    func confirmationDescription(parameters: [String: Any]) -> String {
        if let name = parameters["name"] as? String, !name.isEmpty {
            return "Upgrade package '\(name)' via Homebrew"
        }
        return "Upgrade all outdated Homebrew packages"
    }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        guard await shellService.which("brew") != nil else {
            return .error("Homebrew is not installed. Install it from https://brew.sh")
        }

        var args = ["upgrade"]
        if let name = parameters["name"] as? String, !name.isEmpty {
            args.append(name)
        }

        let result = try await shellService.run(executable: "brew", arguments: args, timeout: 600)
        if result.succeeded {
            let output = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            return .success(output.isEmpty ? "Everything is up to date." : output)
        }
        return .error("Upgrade failed: \(result.stderr)")
    }
}
