import Testing; import Foundation; @testable import Shellmate
@Suite("ShellTool") struct ShellToolTests {
    @Test("echo") func e() async { let r=await ShellTool.execute(input:["command":"echo hello"]); #expect(!r.isError); #expect(r.content.contains("hello")) }
    @Test("pwd") func p() async { #expect(!(await ShellTool.execute(input:["command":"pwd"])).isError) }
    @Test("missing") func m() async { #expect((await ShellTool.execute(input:[:])).isError) }
    @Test("exit code") func ec() async { let r=await ShellTool.execute(input:["command":"exit 42"]); #expect(r.isError); #expect(r.content.contains("42")) }
    @Test("empty output") func eo() async { #expect((await ShellTool.execute(input:["command":"true"])).content=="(no output)") }
    @Test("timeout") func to() async { let r=await ShellTool.execute(input:["command":"sleep 30","timeout":1.0]); #expect(r.isError) }
}
