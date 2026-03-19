import Testing; import Foundation; @testable import Shellmate
@Suite("ToolDefinition") struct ToolDefinitionTests {
    @Test("count") func c() { #expect(ToolDefinitions.all.count==6) }
    @Test("names") func n() { let n=Set(ToolDefinitions.all.map{$0.name}); for t in ["shell_exec","file_read","file_write","file_list","web_search","web_fetch"]{#expect(n.contains(t))} }
    @Test("schemas") func s() { for t in ToolDefinitions.all{#expect(!t.description.isEmpty); #expect(!t.inputSchema.required.isEmpty)} }
    @Test("deny") func d() { #expect(ToolDefinitions.available(denyCategories:[]).count==6); #expect(ToolDefinitions.available(denyCategories:[.exec]).count==5); #expect(ToolDefinitions.available(denyCategories:ToolDenyCategory.allCases).isEmpty) }
    @Test("Codable") func co() throws { #expect(try JSONDecoder().decode(ToolDefinition.self,from:JSONEncoder().encode(ToolDefinitions.shellExec)).name=="shell_exec") }
}
