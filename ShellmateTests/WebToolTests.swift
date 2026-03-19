import Testing; import Foundation; @testable import Shellmate
@Suite("WebSearchTool") struct WebSearchToolTests {
    @Test("missing query") func m() async { #expect((await WebSearchTool.execute(input:[:])).isError) }
    @Test("no API key") func k() async { if ProcessInfo.processInfo.environment["BRAVE_API_KEY"]==nil{#expect((await WebSearchTool.execute(input:["query":"test"])).content.contains("BRAVE_API_KEY"))} }
}
@Suite("WebFetchTool") struct WebFetchToolTests {
    @Test("missing url") func m() async { #expect((await WebFetchTool.execute(input:[:])).isError) }
    @Test("blocks localhost") func l() async { #expect((await WebFetchTool.execute(input:["url":"http://localhost:3000"])).isError) }
    @Test("blocks private") func p() async { #expect((await WebFetchTool.execute(input:["url":"http://192.168.1.1"])).isError) }
    @Test("blocks ftp") func f() async { #expect((await WebFetchTool.execute(input:["url":"ftp://x.com"])).isError) }
}
