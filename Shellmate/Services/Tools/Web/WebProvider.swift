import Foundation

/// Provides web tools: search and fetch.
struct WebProvider: ToolProvider {
    let category = ToolCategory.web
    let displayName = "Web & Search"
    var tools: [AgentTool] { [WebSearchTool(), WebFetchTool()] }
}
