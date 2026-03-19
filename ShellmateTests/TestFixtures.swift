import Foundation
@testable import Shellmate
enum TestFixtures {
    static func sampleAgentSpec() -> AgentSpec {
        AgentSpec(id:"main",name:"Buddy",personality:"Friendly",mission:"Help with Mac tasks",macApps:["Safari","Finder","Terminal"],useCases:["Organize files","Install apps"],failure:"Ask user",escalation:"Contact support",never:["Delete system files","Share passwords"])
    }
    static var emptyAgentSpec: AgentSpec { AgentSpec() }
    static func sampleConfig(setupComplete:Bool=true) -> ShellmateConfig {
        var c = ShellmateConfig(); c.setupComplete=setupComplete; c.agents.list=[AgentListEntry(id:"main",name:"Buddy",workspace:"~/.shellmate/workspace")]; return c
    }
    static var sampleToolCall: ToolCall { ToolCall(id:"tc_001",name:"shell_exec",input:["command":.string("echo hello")]) }
    static var sampleToolResult: ToolResult { ToolResult(id:"tc_001",content:"hello\n",isError:false) }
    static let complexJSONValue: JSONValue = .object(["name":.string("test"),"count":.int(42),"ratio":.double(3.14),"active":.bool(true),"tags":.array([.string("a"),.string("b")]),"nested":.object(["key":.string("value")]),"empty":.null])
    static func makeTempDir(prefix:String="shellmate-test") -> URL {
        let t = FileManager.default.temporaryDirectory.appendingPathComponent("\(prefix)-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at:t,withIntermediateDirectories:true); return t
    }
    static func cleanupTempDir(_ u:URL) { try? FileManager.default.removeItem(at:u) }
}
