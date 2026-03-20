import Foundation

/// Result of a single validation check.
struct ValidationCheck: Identifiable, Sendable {
    let id: String
    let name: String
    var passed: Bool
    var detail: String
}

/// Runs preflight and setup validation checks.
struct ValidationService: Sendable {
    private let configService: ConfigService

    init(configService: ConfigService = ConfigService()) {
        self.configService = configService
    }

    /// Run all validation checks.
    func runAll(aiConfig: AIConfigState) async -> [ValidationCheck] {
        let apiKeyCheck = await checkApiKey(aiConfig: aiConfig)
        return [
            checkConfig(),
            checkWorkspace(),
            apiKeyCheck,
            checkWebSearch(),
        ]
    }

    /// Check that config file exists and is valid.
    func checkConfig() -> ValidationCheck {
        do {
            _ = try configService.readConfig()
            return ValidationCheck(id: "config", name: "Configuration", passed: true, detail: "Config file found and valid")
        } catch {
            return ValidationCheck(id: "config", name: "Configuration", passed: false, detail: error.localizedDescription)
        }
    }

    /// Check that workspace directory exists.
    func checkWorkspace() -> ValidationCheck {
        let exists = FileManager.default.fileExists(atPath: configService.workspacePath.path)
        return ValidationCheck(
            id: "workspace",
            name: "Workspace",
            passed: exists,
            detail: exists ? "Workspace directory found" : "Workspace not found at ~/.shellmate/workspace"
        )
    }

    /// Check that an API key is available.
    @MainActor
    func checkApiKey(aiConfig: AIConfigState) -> ValidationCheck {
        let key = aiConfig.resolveApiKey()
        let hasKey = key.map({ !$0.isEmpty }) ?? false
        return ValidationCheck(
            id: "apiKey",
            name: "API Key",
            passed: hasKey,
            detail: hasKey ? "API key configured" : "No API key found"
        )
    }

    /// Check that Brave Search API key is available (optional).
    func checkWebSearch() -> ValidationCheck {
        let key = ProcessInfo.processInfo.environment["BRAVE_API_KEY"]
        let hasKey = key.map({ !$0.isEmpty }) ?? false
        return ValidationCheck(
            id: "webSearch",
            name: "Web Search",
            passed: hasKey,
            detail: hasKey ? "Brave Search API key found" : "Web search unavailable (no BRAVE_API_KEY)"
        )
    }
}
