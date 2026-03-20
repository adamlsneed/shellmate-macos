import Foundation

/// Checks whether a specific application or package is installed via Homebrew.
struct AppCheckInstalledTool: AgentTool {
    let identifier = "app_check_installed"
    let toolDescription = "Check if a specific application or package is installed via Homebrew."
    let category = ToolCategory.apps
    let actionTier = ActionTier.read
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "name": ToolProperty(type: "string", description: "Name of the package or cask to check"),
        ],
        required: ["name"]
    )

    private let shellService: ShellService
    init(shellService: ShellService) { self.shellService = shellService }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        guard let name = parameters["name"] as? String, !name.isEmpty else {
            return .error("Missing required parameter: name")
        }

        guard await shellService.which("brew") != nil else {
            return .error("Homebrew is not installed. Install it from https://brew.sh")
        }

        // Check formulae
        let formulaResult = try await shellService.run(executable: "brew", arguments: ["list", "--formula"])
        let formulae = Set(formulaResult.stdout.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) })

        // Check casks
        let caskResult = try await shellService.run(executable: "brew", arguments: ["list", "--cask"])
        let casks = Set(caskResult.stdout.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) })

        let lowerName = name.lowercased()
        if formulae.contains(where: { $0.lowercased() == lowerName }) {
            return .success("'\(name)' is installed as a Homebrew formula.")
        } else if casks.contains(where: { $0.lowercased() == lowerName }) {
            return .success("'\(name)' is installed as a Homebrew cask.")
        } else {
            return .success("'\(name)' is not installed via Homebrew.")
        }
    }
}
