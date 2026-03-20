import Foundation

// MARK: - SetupDeveloperToolsTool

/// Checks for Xcode Command Line Tools and triggers installation if missing.
struct SetupDeveloperToolsTool: AgentTool {
    let identifier = "setup_developer_tools"
    let toolDescription = "Check if Xcode Command Line Developer Tools are installed, and trigger installation if missing."
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
        "I'd like to check if Xcode Command Line Developer Tools are installed, and install them if missing. These tools include git, make, clang, and other essential developer utilities."
    }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        // Check if xcode-select path is set (tools installed)
        do {
            let result = try await shellService.run(executable: "xcode-select", arguments: ["-p"])
            if result.succeeded {
                let path = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
                return .success("Xcode Command Line Tools are installed at: \(path)")
            }
        } catch {
            // Not installed — fall through to install
        }

        // Not installed — trigger the system install dialog
        do {
            let result = try await shellService.run(executable: "xcode-select", arguments: ["--install"])
            if result.succeeded {
                return .success("Xcode Command Line Tools installation has been triggered. A system dialog should appear — follow the prompts to complete installation.")
            } else {
                var output = result.stdout
                if !result.stderr.isEmpty {
                    output += (output.isEmpty ? "" : "\n") + result.stderr
                }
                // xcode-select --install may exit non-zero if already installing
                if output.lowercased().contains("already") {
                    return .success("Xcode Command Line Tools installation is already in progress.")
                }
                return .error("Failed to trigger installation (exit code \(result.exitCode)). \(output)")
            }
        } catch let error as ShellServiceError {
            return .error("Failed to install developer tools: \(error.localizedDescription)")
        }
    }
}
