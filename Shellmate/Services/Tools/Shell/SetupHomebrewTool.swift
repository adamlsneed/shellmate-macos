import Foundation

// MARK: - SetupHomebrewTool

/// Checks for Homebrew and installs it if missing.
struct SetupHomebrewTool: AgentTool {
    let identifier = "setup_homebrew"
    let toolDescription = "Check if Homebrew is installed and return its version, or install it if missing. Homebrew is the standard macOS package manager."
    let category = ToolCategory.shell
    let actionTier = ActionTier.write
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [:],
        required: []
    )

    private let shellService: ShellService
    init(service: ShellService) { self.shellService = service }

    func confirmationDescription(parameters: [String: Any]) -> String {
        "I'd like to check if Homebrew (the macOS package manager) is installed, and install it if it's missing. Homebrew lets you install developer tools and apps from the command line."
    }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        // Check if brew is already installed
        if let brewPath = await shellService.which("brew") {
            do {
                let result = try await shellService.run(executable: brewPath.path, arguments: ["--version"])
                let version = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
                return .success("Homebrew is installed.\n\(version)")
            } catch {
                return .success("Homebrew is installed at \(brewPath.path) but could not determine version.")
            }
        }

        // Not installed — run the official install script
        do {
            let result = try await shellService.runCommand(
                "/bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"",
                timeout: 600
            )

            if result.succeeded {
                return .success("Homebrew installed successfully.\n\(result.stdout)")
            } else {
                var output = result.stdout
                if !result.stderr.isEmpty {
                    output += "\nSTDERR: \(result.stderr)"
                }
                return .error("Homebrew installation failed (exit code \(result.exitCode)).\n\(output)")
            }
        } catch let error as ShellServiceError {
            return .error("Failed to install Homebrew: \(error.localizedDescription)")
        }
    }
}
