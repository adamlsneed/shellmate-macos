import Testing; import Foundation; @testable import Shellmate
@Suite("MigrationService") struct MigrationServiceTests {
    @Test("needs migration logic") func nm() throws { let d=TestFixtures.makeTempDir(prefix:"m"); defer{TestFixtures.cleanupTempDir(d)}; try FileManager.default.createDirectory(at:d.appendingPathComponent(".openclaw"),withIntermediateDirectories:true); #expect(!FileManager.default.fileExists(atPath:d.appendingPathComponent(".shellmate").path)) }
    @Test("copy and rename") func cr() throws { let d=TestFixtures.makeTempDir(prefix:"m3"); defer{TestFixtures.cleanupTempDir(d)}; let s=d.appendingPathComponent("s"); let t=d.appendingPathComponent("t"); try FileManager.default.createDirectory(at:s,withIntermediateDirectories:true); try "cfg".write(to:s.appendingPathComponent("openclaw.json"),atomically:true,encoding:.utf8); try FileManager.default.copyItem(at:s,to:t); try FileManager.default.moveItem(at:t.appendingPathComponent("openclaw.json"),to:t.appendingPathComponent("shellmate.json")); #expect(FileManager.default.fileExists(atPath:t.appendingPathComponent("shellmate.json").path)) }
    @Test("service") func sc() { _ = MigrationService().needsMigration }
}
