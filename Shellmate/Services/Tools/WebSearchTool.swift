import Foundation
import os

/// Brave Search API client for the web_search tool.
enum WebSearchTool {
    private static let logger = Logger(subsystem: "com.shellmate.app", category: "web-search")
    private static let baseURL = "https://api.search.brave.com/res/v1/web/search"

    static func execute(input: [String: Any]) async -> ToolExecutionResult {
        guard let query = input["query"] as? String else {
            return ToolExecutionResult(content: "Missing required 'query' parameter", isError: true)
        }

        guard let apiKey = ProcessInfo.processInfo.environment["BRAVE_API_KEY"], !apiKey.isEmpty else {
            return ToolExecutionResult(content: "Web search unavailable: BRAVE_API_KEY not set", isError: true)
        }

        let count = min((input["count"] as? Int) ?? 5, 20)

        var components = URLComponents(string: baseURL)!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "count", value: "\(count)"),
        ]

        guard let url = components.url else {
            return ToolExecutionResult(content: "Failed to build search URL", isError: true)
        }

        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "X-Subscription-Token")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return ToolExecutionResult(content: "Search API error", isError: true)
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let web = json["web"] as? [String: Any],
                  let results = web["results"] as? [[String: Any]] else {
                return ToolExecutionResult(content: "No results found", isError: false)
            }

            let formatted = results.prefix(count).map { result in
                let title = result["title"] as? String ?? "Untitled"
                let url = result["url"] as? String ?? ""
                let desc = result["description"] as? String ?? ""
                return "**\(title)**\n\(url)\n\(desc)"
            }.joined(separator: "\n\n")

            return ToolExecutionResult(content: formatted, isError: false)
        } catch {
            return ToolExecutionResult(content: "Search failed: \(error.localizedDescription)", isError: true)
        }
    }
}
