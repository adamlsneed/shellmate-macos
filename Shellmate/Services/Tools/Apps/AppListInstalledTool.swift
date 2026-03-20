import Foundation

/// Lists all applications and packages installed via Homebrew.
struct AppListInstalledTool: AgentTool {
    let identifier = "app_list_installed"
    let toolDescription = "List all applications and packages installed via Homebrew, separated into formulae and casks."
    let category = ToolCategory.apps
    let actionTier = ActionTier.read
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [:],
        required: []
    )

    private let shellService: ShellService
    init(shellService: ShellService) { self.shellService = shellService }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        guard await shellService.which("brew") != nil else {
            return .error("Homebrew is not installed. Install it from https://brew.sh")
        }

        var sections: [String] = []

        let formulaResult = try await shellService.run(executable: "brew", arguments: ["list", "--formula"])
        if formulaResult.succeeded {
            let output = formulaResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            sections.append("--- Formulae ---\n\(output.isEmpty ? "(none)" : output)")
        }

        let caskResult = try await shellService.run(executable: "brew", arguments: ["list", "--cask"])
        if caskResult.succeeded {
            let output = caskResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            sections.append("--- Casks ---\n\(output.isEmpty ? "(none)" : output)")
        }

        return sections.isEmpty ? .error("Failed to list installed packages.") : .success(sections.joined(separator: "\n\n"))
    }
}
