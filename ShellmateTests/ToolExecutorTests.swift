import Testing; import Foundation; @testable import Shellmate
@Suite("ToolExecutor") struct ToolExecutorTests {
    @Test("shell_exec") func s() async { let r=await ToolExecutor().execute(tool:"shell_exec",input:["command":.string("echo hi")]); #expect(!r.isError); #expect(r.content.contains("hi")) }
    @Test("file_read") func fr() async { #expect((await ToolExecutor().execute(tool:"file_read",input:["path":.string("/tmp/ne_\(UUID())")])).isError) }
    @Test("unknown") func u() async { let r=await ToolExecutor().execute(tool:"nope",input:[:]); #expect(r.isError); #expect(r.content.contains("Unknown")) }
}
