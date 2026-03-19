import Testing; import Foundation; @testable import Shellmate
@Suite("ChatMessage") struct ChatMessageTests {
    @Test("defaults") func testDefaults() { let m=ChatMessage(role:.user,content:"Hi"); #expect(!m.id.isEmpty); #expect(m.role == .user); #expect(m.toolCalls.isEmpty) }
    @Test("custom ID") func testID() { #expect(ChatMessage(id:"x",role:.user,content:"").id=="x") }
    @Test("MessageRole Codable") func testRole() throws { for r in [MessageRole.user,.assistant,.system,.tool] { #expect(try JSONDecoder().decode(MessageRole.self,from:JSONEncoder().encode(r))==r) } }
    @Test("ToolCall Codable") func testTC() throws { let t=ToolCall(id:"1",name:"shell_exec",input:["command":.string("echo")]); let d=try JSONDecoder().decode(ToolCall.self,from:JSONEncoder().encode(t)); #expect(d.id=="1"); #expect(d.input["command"] == .string("echo")) }
    @Test("ToolResult Codable") func testTR() throws { let d=try JSONDecoder().decode(ToolResult.self,from:JSONEncoder().encode(ToolResult(id:"1",content:"ok",isError:false))); #expect(!d.isError) }
    @Test("ToolResult error") func testTRE() throws { #expect(try JSONDecoder().decode(ToolResult.self,from:JSONEncoder().encode(ToolResult(id:"2",content:"err",isError:true))).isError) }
}
