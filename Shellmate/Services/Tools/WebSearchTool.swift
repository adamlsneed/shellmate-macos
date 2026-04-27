import Foundation
import os

/// Brave Search API client for the web_search tool.
struct WebSearchTool: AgentTool {
    let identifier = "web_search"
    let toolDescription = "Search the web using Brave Search. Returns titles, URLs, and descriptions of results."
    let category = ToolCategory.web
    let actionTier = ActionTier.read

    var parameterSchema: ToolInputSchema {
        ToolInputSchema(
            type: "object",
            properties: [
                "query": ToolProperty(type: "string", description: "The search query"),
                "count": ToolProperty(type: "integer", description: "Number of results (default 5, max 20)"),
            ],
            required: ["query"]
        )
    }

    private static let logger = Logger(subsystem: "com.shellmate.app", category: "web-search")
    private static let baseURL = "https://api.search.brave.com/res/v1/web/search"

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        guard let query = parameters["query"] as? String else {
            return .error("Missing required 'query' parameter")
        }

        guard let apiKey = Self.resolveAPIKey() else {
            return .error("Web search unavailable: BRAVE_API_KEY or Brave key in Settings not set")
        }

        let count = min((parameters["count"] as? Int) ?? 5, 20)

        guard var components = URLComponents(string: Self.baseURL) else {
            return .error("Invalid search base URL")
        }
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "count", value: "\(count)"),
        ]

        guard let url = components.url else {
            return .error("Failed to build search URL")
        }

        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "X-Subscription-Token")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            return .error("Search API error")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let web = json["web"] as? [String: Any],
              let results = web["results"] as? [[String: Any]] else {
            return .success("No results found")
        }

        let formatted = results.prefix(count).map { result in
            let title = result["title"] as? String ?? "Untitled"
            let resultURL = result["url"] as? String ?? ""
            let desc = result["description"] as? String ?? ""
            return "**\(title)**\n\(resultURL)\n\(desc)"
        }.joined(separator: "\n\n")

        return .success(formatted)
    }

    static func resolveAPIKey(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        keychainValue: String? = KeychainHelper.read(service: KeychainHelper.apiKeyService, account: "brave")
    ) -> String? {
        if let envKey = environment["BRAVE_API_KEY"], !envKey.isEmpty {
            return envKey
        }
        if let keychainValue, !keychainValue.isEmpty {
            return keychainValue
        }
        return nil
    }
}
