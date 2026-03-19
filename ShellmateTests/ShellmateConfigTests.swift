import Testing; import Foundation; @testable import Shellmate
@Suite("ShellmateConfig") struct ShellmateConfigTests {
    @Test("defaults") func d() { let c=ShellmateConfig(); #expect(c.version=="1.0"); #expect(!c.setupComplete); #expect(c.capabilities.webSearch) }
    @Test("round-trip") func rt() throws { let c=TestFixtures.sampleConfig(); let r=try JSONDecoder().decode(ShellmateConfig.self,from:JSONEncoder().encode(c)); #expect(r.setupComplete); #expect(r.agents.list[0].name=="Buddy") }
    @Test("ToolPermissions") func tp() throws { #expect(try JSONDecoder().decode(ToolPermissions.self,from:JSONEncoder().encode(ToolPermissions(deny:["exec"]))).deny==["exec"]) }
    @Test("CapabilitiesConfig") func cc() throws { var c=CapabilitiesConfig(); c.webSearch=false; c.tools.deny=["exec"]; let r=try JSONDecoder().decode(CapabilitiesConfig.self,from:JSONEncoder().encode(c)); #expect(!r.webSearch); #expect(r.tools.deny==["exec"]) }
}
