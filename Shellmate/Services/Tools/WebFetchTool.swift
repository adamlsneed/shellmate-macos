import Foundation
import SwiftSoup
import os

/// Fetches web pages and extracts text content.
enum WebFetchTool {
    private static let logger = Logger(subsystem: "com.shellmate.app", category: "web-fetch")
    private static let maxChars = 50_000
    private static let timeout: TimeInterval = 15

    static func execute(input: [String: Any]) async -> ToolExecutionResult {
        guard let urlString = input["url"] as? String else {
            return ToolExecutionResult(content: "Missing required 'url' parameter", isError: true)
        }

        if SecurityPolicy.isURLBlocked(urlString) {
            return ToolExecutionResult(content: "Access denied: URL is restricted (private IP or non-HTTP)", isError: true)
        }

        guard let url = URL(string: urlString) else {
            return ToolExecutionResult(content: "Invalid URL: \(urlString)", isError: true)
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36",
            forHTTPHeaderField: "User-Agent"
        )

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return ToolExecutionResult(content: "Invalid response", isError: true)
            }
            guard (200...299).contains(httpResponse.statusCode) else {
                return ToolExecutionResult(content: "HTTP \(httpResponse.statusCode)", isError: true)
            }

            guard let html = String(data: data, encoding: .utf8) else {
                return ToolExecutionResult(content: "Failed to decode response as text", isError: true)
            }

            // Extract text from HTML using SwiftSoup
            let text = extractText(from: html)
            let truncated = text.count > maxChars
                ? String(text.prefix(maxChars)) + "\n...[truncated]"
                : text

            return ToolExecutionResult(content: truncated, isError: false)
        } catch {
            return ToolExecutionResult(content: "Fetch failed: \(error.localizedDescription)", isError: true)
        }
    }

    /// Extract readable text from HTML using SwiftSoup.
    private static func extractText(from html: String) -> String {
        do {
            let doc = try SwiftSoup.parse(html)

            // Remove script and style elements
            try doc.select("script, style, nav, footer, header").remove()

            // Get text content
            let text = try doc.text()
            return text
        } catch {
            // Fallback: basic regex strip
            return html
                .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
}
