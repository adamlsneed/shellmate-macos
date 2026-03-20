import Foundation

/// Provides web tools: search, fetch, download, and app discovery.
struct WebProvider: ToolProvider {
    let category = ToolCategory.web
    let displayName = "Web & Search"

    private let shellService: ShellService?
    init(shellService: ShellService? = nil) { self.shellService = shellService }

    var tools: [AgentTool] {
        var result: [AgentTool] = [WebSearchTool(), WebFetchTool()]
        if let shellService {
            result.append(WebDownloadTool(shellService: shellService))
            result.append(AppDiscoverTool(shellService: shellService))
        }
        return result
    }
}
