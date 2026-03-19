import Foundation
import SwiftSoup
import os

/// Fetches web pages and extracts text content.
struct WebFetchTool: AgentTool {
    let identifier = "web_fetch"
    let toolDescription = "Fetch the contents of a web page and extract the text."
    let category = ToolCategory.web
    let actionTier = ActionTier.read

    var parameterSchema: ToolInputSchema {
        ToolInputSchema(
            type: "object",
            properties: [
                "url": ToolProperty(type: "string", description: "The URL to fetch"),
            ],
            required: ["url"]
        )
    }

    private static let logger = Logger(subsystem: "com.shellmate.app", category: "web-fetch")
    private static let maxChars = 50_000
    private static let maxDownloadBytes = 5_000_000 // 5MB
    private static let timeout: TimeInterval = 15

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        guard let urlString = parameters["url"] as? String else {
            return .error("Missing required 'url' parameter")
        }

        if SecurityPolicy.isURLBlocked(urlString) {
            return .error("Access denied: URL is restricted (private IP or non-HTTP)")
        }

        guard let url = URL(string: urlString) else {
            return .error("Invalid URL: \(urlString)")
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = Self.timeout
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36",
            forHTTPHeaderField: "User-Agent"
        )

        let session = SSRFProtectedSession.shared
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            return .error("Invalid response")
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            return .error("HTTP \(httpResponse.statusCode)")
        }

        if data.count > Self.maxDownloadBytes {
            return .error("Response too large (\(data.count) bytes, max \(Self.maxDownloadBytes))")
        }

        guard let html = String(data: data, encoding: .utf8) else {
            return .error("Failed to decode response as text")
        }

        let text = Self.extractText(from: html)
        let truncated = text.count > Self.maxChars
            ? String(text.prefix(Self.maxChars)) + "\n...[truncated]"
            : text

        return .success(truncated)
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

// MARK: - Backward Compatibility

// Temporary compat — removed when ToolExecutor is refactored in Task 8
extension WebFetchTool {
    static func execute(input: [String: Any]) async -> ToolExecutionResult {
        let tool = WebFetchTool()
        do {
            let result = try await tool.execute(parameters: input)
            return ToolExecutionResult(content: result.content, isError: result.isError)
        } catch {
            return ToolExecutionResult(content: error.localizedDescription, isError: true)
        }
    }
}

// MARK: - SSRF-Protected URL Session

/// URLSession delegate that validates redirect targets against SecurityPolicy.
/// Prevents SSRF attacks via HTTP redirects to private/internal IPs.
final class SSRFRedirectDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    private static let logger = Logger(subsystem: "com.shellmate.app", category: "ssrf-guard")

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping @Sendable (URLRequest?) -> Void
    ) {
        guard let url = request.url?.absoluteString else {
            completionHandler(nil)
            return
        }

        if SecurityPolicy.isURLBlocked(url) {
            Self.logger.warning("Blocked redirect to restricted URL: \(url)")
            completionHandler(nil)
        } else {
            completionHandler(request)
        }
    }
}

/// Singleton URL session configured with SSRF redirect protection.
enum SSRFProtectedSession {
    private static let delegate = SSRFRedirectDelegate()

    static let shared: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForResource = 30
        return URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
    }()
}
