import Foundation

/// Lists outdated Homebrew packages that can be upgraded.
struct AppOutdatedTool: AgentTool {
    let identifier = "app_outdated"
    let toolDescription = "List outdated Homebrew packages that have newer versions available."
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

        let result = try await shellService.run(executable: "brew", arguments: ["outdated"])
        if result.succeeded {
            let output = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            return .success(output.isEmpty ? "All packages are up to date." : output)
        }
        return .error("Failed to check outdated packages: \(result.stderr)")
    }
}
