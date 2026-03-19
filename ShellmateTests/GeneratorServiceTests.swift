import Testing
import Foundation
@testable import Shellmate

@Suite("GeneratorService") struct GeneratorServiceTests {
    let agent = TestFixtures.sampleAgentSpec()
    let emptyAgent = TestFixtures.emptyAgentSpec

    @Test("generateAll produces 9 files") func testCount() { #expect(GeneratorService.generateAll(agent: agent).count == 9) }
    @Test("generateAll unique IDs") func testIDs() { #expect(Set(GeneratorService.generateAll(agent: agent).map(\.id)).count == 9) }
    @Test("all expected filenames") func testNames() {
        let n = Set(GeneratorService.generateAll(agent: agent).map(\.filename))
        #expect(n.contains("SOUL.md")); #expect(n.contains("AGENTS.md")); #expect(n.contains("IDENTITY.md"))
        #expect(n.contains("USER.md")); #expect(n.contains("TOOLS.md")); #expect(n.contains("BOOTSTRAP.md"))
        #expect(n.contains("MEMORY.md")); #expect(n.contains("memory/README.md")); #expect(n.contains("skills/README.md"))
    }
    @Test("SOUL has name") func s1() { #expect(GeneratorService.generateSOUL(agent: agent).contains("**Buddy**")) }
    @Test("SOUL has personality") func s2() { #expect(GeneratorService.generateSOUL(agent: agent).contains("## Personality")) }
    @Test("SOUL has NEVER rules") func s3() { #expect(GeneratorService.generateSOUL(agent: agent).contains("- **NEVER** Delete system files")) }
    @Test("SOUL empty fallback") func s4() { #expect(GeneratorService.generateSOUL(agent: emptyAgent).contains("**Shellmate**")) }
    @Test("IDENTITY has name") func i1() { #expect(GeneratorService.generateIdentity(agent: agent).contains("**Name:** Buddy")) }
    @Test("TOOLS has apps") func t1() { #expect(GeneratorService.generateTools(agent: agent).contains("- Safari")) }
    @Test("AGENTS has startup") func a1() { #expect(GeneratorService.generateAgents(agent: agent).contains("Read `SOUL.md`")) }
    @Test("AGENTS has safety") func a2() { #expect(GeneratorService.generateAgents(agent: agent).contains("## Safety Boundaries")) }
    @Test("USER has apps") func u1() { #expect(GeneratorService.generateUser(agent: agent).contains("**Safari:**")) }
    @Test("BOOTSTRAP has name") func b1() { #expect(GeneratorService.generateBootstrap(agent: agent).contains("**Buddy**")) }
    @Test("MEMORY has role") func m1() { #expect(GeneratorService.generateMemory(agent: agent).contains("**Buddy**")) }
    @Test("memory README") func mr1() { #expect(GeneratorService.generateMemoryReadme().contains("YYYY-MM-DD.md")) }
    @Test("skills README") func sk1() { #expect(GeneratorService.generateSkillsReadme(agent: agent).contains("clawhub install")) }
}
