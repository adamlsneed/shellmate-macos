import Foundation

/// Discovers and recommends applications based on a described need using Homebrew search.
struct AppDiscoverTool: AgentTool {
    let identifier = "app_discover"
    let toolDescription = "Discover and recommend applications for a given need by searching Homebrew for matching packages and casks."
    let category = ToolCategory.web
    let actionTier = ActionTier.read
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "need": ToolProperty(type: "string", description: "Natural language description of what you need an app for (e.g. 'video editor', 'password manager')"),
        ],
        required: ["need"]
    )

    private let shellService: ShellService
    init(shellService: ShellService) { self.shellService = shellService }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        guard let need = parameters["need"] as? String, !need.isEmpty else {
            return .error("Missing required parameter: need")
        }

        guard await shellService.which("brew") != nil else {
            return .error("Homebrew is not installed. Install it from https://brew.sh")
        }

        // Extract keywords from the need description
        let keywords = need.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 2 }

        var allResults: [String] = []

        // Search brew for each keyword
        for keyword in keywords.prefix(3) {
            let result = try await shellService.run(executable: "brew", arguments: ["search", keyword])
            if result.succeeded {
                let matches = result.stdout
                    .split(separator: "\n")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty && !$0.hasPrefix("==>") }
                allResults.append(contentsOf: matches)
            }
        }

        // Deduplicate and limit
        let unique = Array(Set(allResults)).sorted().prefix(30)

        if unique.isEmpty {
            return .success("No Homebrew packages found matching '\(need)'. Try different search terms or check the Mac App Store.")
        }

        return .success("Homebrew packages matching '\(need)':\n\(unique.joined(separator: "\n"))\n\nUse app_install to install any of these. Use 'brew info <name>' for details.")
    }
}
