import Testing
import Foundation
@testable import Shellmate

@Suite("MigrationService") struct MigrationServiceTests {
    @Test("needsMigration false when no legacy") func t1() {
        let tmp = TestFixtures.makeTempDir(prefix: "mig")
        defer { TestFixtures.cleanupTempDir(tmp) }
        #expect(!MigrationService(legacyDir: tmp.appendingPathComponent("x"), targetDir: tmp.appendingPathComponent("y")).needsMigration)
    }
    @Test("migrate copies and updates paths") func t2() throws {
        let tmp = TestFixtures.makeTempDir(prefix: "mig2")
        defer { TestFixtures.cleanupTempDir(tmp) }
        let legacy = tmp.appendingPathComponent(".openclaw")
        try FileManager.default.createDirectory(at: legacy, withIntermediateDirectories: true)
        let cfg: [String: Any] = ["agents": ["defaults": ["workspace": "~/.openclaw/workspace"]]]
        try JSONSerialization.data(withJSONObject: cfg).write(to: legacy.appendingPathComponent("openclaw.json"))
        let target = tmp.appendingPathComponent(".shellmate")
        try MigrationService(legacyDir: legacy, targetDir: target).migrate()
        #expect(FileManager.default.fileExists(atPath: target.appendingPathComponent("shellmate.json").path))
        let d = try Data(contentsOf: target.appendingPathComponent("shellmate.json"))
        let j = try JSONSerialization.jsonObject(with: d) as! [String: Any]
        let a = (j["agents"] as! [String: Any])["defaults"] as! [String: Any]
        #expect((a["workspace"] as! String) == "~/.shellmate/workspace")
    }
    @Test("migrate throws no source") func t3() {
        let tmp = TestFixtures.makeTempDir(prefix: "mig3")
        defer { TestFixtures.cleanupTempDir(tmp) }
        #expect(throws: MigrationError.self) { try MigrationService(legacyDir: tmp.appendingPathComponent("x"), targetDir: tmp.appendingPathComponent("y")).migrate() }
    }
}
