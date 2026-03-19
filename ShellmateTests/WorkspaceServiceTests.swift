import Testing
import Foundation
@testable import Shellmate

@Suite("WorkspaceService") struct WorkspaceServiceTests {
    @Test("writeFile creates file") func t1() throws {
        let (cs, tmp) = TestFixtures.makeIsolatedConfigService()
        defer { TestFixtures.cleanupTempDir(tmp) }
        let ws = WorkspaceService(configService: cs)
        try ws.writeFile(name: "SOUL.md", content: "# Soul")
        #expect(ws.fileExists(name: "SOUL.md"))
        #expect(try ws.readFile(name: "SOUL.md") == "# Soul")
    }
    @Test("writeFile nested dirs") func t2() throws {
        let (cs, tmp) = TestFixtures.makeIsolatedConfigService()
        defer { TestFixtures.cleanupTempDir(tmp) }
        try WorkspaceService(configService: cs).writeFile(name: "memory/README.md", content: "# L")
    }
    @Test("writeFile backup") func t3() throws {
        let (cs, tmp) = TestFixtures.makeIsolatedConfigService()
        defer { TestFixtures.cleanupTempDir(tmp) }
        let ws = WorkspaceService(configService: cs)
        try ws.writeFile(name: "SOUL.md", content: "old")
        try ws.writeFile(name: "SOUL.md", content: "new")
        #expect(try ws.readFile(name: "SOUL.md") == "new")
        #expect(ws.listFiles().contains { $0.contains(".bak-") })
    }
    @Test("detectConflicts") func t4() throws {
        let (cs, tmp) = TestFixtures.makeIsolatedConfigService()
        defer { TestFixtures.cleanupTempDir(tmp) }
        let ws = WorkspaceService(configService: cs)
        try ws.writeFile(name: "SOUL.md", content: "#")
        let r = ws.detectConflicts(files: [GeneratedFile(id: "s", filename: "SOUL.md", content: "x"), GeneratedFile(id: "i", filename: "ID.md", content: "y")])
        #expect(r[0].existsOnDisk); #expect(!r[1].existsOnDisk)
    }
    @Test("readAllAsSystemPrompt") func t5() throws {
        let (cs, tmp) = TestFixtures.makeIsolatedConfigService()
        defer { TestFixtures.cleanupTempDir(tmp) }
        let ws = WorkspaceService(configService: cs)
        try ws.writeFile(name: "SOUL.md", content: "# Soul")
        #expect(ws.readAllAsSystemPrompt().contains("# Soul"))
    }
}
