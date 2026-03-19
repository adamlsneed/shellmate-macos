import Testing; import Foundation; @testable import Shellmate
@Suite("WebSearchTool") struct WebSearchToolTests {
    @Test("missing query") func m() async { #expect((await WebSearchTool.execute(input:[:])).isError) }
    @Test("no API key") func k() async { if ProcessInfo.processInfo.environment["BRAVE_API_KEY"]==nil{#expect((await WebSearchTool.execute(input:["query":"test"])).content.contains("BRAVE_API_KEY"))} }

    // Instance API tests
    @Test("instance missing query") func instanceMissing() async throws {
        let result = try await WebSearchTool().execute(parameters: [:])
        #expect(result.isError)
        #expect(result.content.contains("Missing"))
    }

    @Test("instance no API key") func instanceNoKey() async throws {
        if ProcessInfo.processInfo.environment["BRAVE_API_KEY"] == nil {
            let result = try await WebSearchTool().execute(parameters: ["query": "test"])
            #expect(result.isError)
            #expect(result.content.contains("BRAVE_API_KEY"))
        }
    }

    @Test("protocol properties") func props() {
        let tool = WebSearchTool()
        #expect(tool.identifier == "web_search")
        #expect(tool.category == .web)
        #expect(tool.actionTier == .read)
        #expect(tool.parameterSchema.required == ["query"])
    }
}
@Suite("WebFetchTool") struct WebFetchToolTests {
    @Test("missing url") func m() async { #expect((await WebFetchTool.execute(input:[:])).isError) }
    @Test("blocks localhost") func l() async { #expect((await WebFetchTool.execute(input:["url":"http://localhost:3000"])).isError) }
    @Test("blocks private") func p() async { #expect((await WebFetchTool.execute(input:["url":"http://192.168.1.1"])).isError) }
    @Test("blocks ftp") func f() async { #expect((await WebFetchTool.execute(input:["url":"ftp://x.com"])).isError) }

    // Instance API tests
    @Test("instance missing url") func instanceMissing() async throws {
        let result = try await WebFetchTool().execute(parameters: [:])
        #expect(result.isError)
        #expect(result.content.contains("Missing"))
    }

    @Test("instance blocks localhost") func instanceBlocksLocalhost() async throws {
        let result = try await WebFetchTool().execute(parameters: ["url": "http://localhost:3000"])
        #expect(result.isError)
        #expect(result.content.contains("restricted"))
    }

    @Test("protocol properties") func props() {
        let tool = WebFetchTool()
        #expect(tool.identifier == "web_fetch")
        #expect(tool.category == .web)
        #expect(tool.actionTier == .read)
        #expect(tool.parameterSchema.required == ["url"])
    }
}

// MARK: - WebProvider

@Suite("WebProvider") struct WebProviderTests {
    @Test("provides all web tools") func allTools() {
        let provider = WebProvider()
        #expect(provider.category == .web)
        #expect(provider.displayName == "Web & Search")
        let ids = provider.tools.map(\.identifier)
        #expect(ids.contains("web_search"))
        #expect(ids.contains("web_fetch"))
        #expect(ids.count == 2)
    }
}
