import Testing; import Foundation; @testable import Shellmate
@Suite("GeneratorService") struct GeneratorServiceTests {
    let agent=TestFixtures.sampleAgentSpec(); let empty=TestFixtures.emptyAgentSpec
    @Test("count") func c() { #expect(GeneratorService.generateAll(agent:agent).count==8) }
    @Test("unique IDs") func u() { #expect(Set(GeneratorService.generateAll(agent:agent).map{$0.id}).count==8) }
    @Test("filenames") func f() { for f in GeneratorService.generateAll(agent:agent) { #expect(f.filename.hasSuffix(".md")) } }
    @Test("expected files") func e() { let n=Set(GeneratorService.generateAll(agent:agent).map{$0.filename}); for x in ["SOUL.md","IDENTITY.md","TOOLS.md","BOUNDARIES.md","ESCALATION.md","MAC.md","MEMORY.md","SYSTEM.md"]{#expect(n.contains(x))} }
    @Test("no empty") func ne() { for f in GeneratorService.generateAll(agent:agent) { #expect(!f.content.isEmpty) } }
    @Test("empty spec") func es() { let fs=GeneratorService.generateAll(agent:empty); #expect(fs.count==8); for f in fs{#expect(!f.content.isEmpty)} }
    @Test("SOUL") func soul() { let c=GeneratorService.generateSOUL(agent:agent); #expect(c.contains(agent.name)); #expect(c.contains(agent.mission)) }
    @Test("SOUL fallback") func sf() { var a=agent; a.failure=""; #expect(GeneratorService.generateSOUL(agent:a).contains("Not specified")) }
    @Test("IDENTITY") func id() { #expect(GeneratorService.generateIdentity(agent:agent).contains(agent.name)) }
    @Test("TOOLS") func t() { let c=GeneratorService.generateTools(agent:agent); for t in ["shell_exec","file_read","file_write","file_list","web_search","web_fetch"]{#expect(c.contains(t))} }
    @Test("BOUNDARIES") func b() { for r in agent.never{#expect(GeneratorService.generateBoundaries(agent:agent).contains(r))} }
    @Test("BOUNDARIES empty") func be() { #expect(GeneratorService.generateBoundaries(agent:empty).contains("No specific restrictions")) }
    @Test("ESCALATION") func esc() { #expect(GeneratorService.generateEscalation(agent:agent).contains(agent.escalation)) }
    @Test("MAC apps") func m() { for app in agent.macApps{#expect(GeneratorService.generateMac(agent:agent).contains(app))} }
    @Test("MEMORY") func mem() { #expect(GeneratorService.generateMemory(agent:agent).contains("core memory")) }
    @Test("SYSTEM") func sys() { let c=GeneratorService.generateSystem(agent:agent); #expect(c.contains(agent.name)); #expect(c.contains("macOS")) }
}
