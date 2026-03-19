import Testing; import Foundation; @testable import Shellmate
@Suite("FileReadTool") struct FileReadToolTests {
    @Test("reads") func r() throws { let d=TestFixtures.makeTempDir(prefix:"fr"); defer{TestFixtures.cleanupTempDir(d)}; let f=d.appendingPathComponent("t.txt"); try "Hi".write(to:f,atomically:true,encoding:.utf8); let r=FileReadTool.execute(input:["path":f.path]); #expect(!r.isError); #expect(r.content=="Hi") }
    @Test("nonexistent") func ne() { #expect(FileReadTool.execute(input:["path":"/tmp/ne_\(UUID())"]).isError) }
    @Test("missing") func m() { #expect(FileReadTool.execute(input:[:]).isError) }
    @Test("blocked") func b() { #expect(FileReadTool.execute(input:["path":"\(FileManager.default.homeDirectoryForCurrentUser.path)/.ssh/id_rsa"]).isError) }
    @Test("oversize") func o() throws { let d=TestFixtures.makeTempDir(prefix:"fr-s"); defer{TestFixtures.cleanupTempDir(d)}; try Data(repeating:65,count:3*1024*1024).write(to:d.appendingPathComponent("big")); #expect(FileReadTool.execute(input:["path":d.appendingPathComponent("big").path]).isError) }
}
@Suite("FileWriteTool") struct FileWriteToolTests {
    @Test("writes") func w() throws { let d=TestFixtures.makeTempDir(prefix:"fw"); defer{TestFixtures.cleanupTempDir(d)}; let f=d.appendingPathComponent("o.txt"); #expect(!FileWriteTool.execute(input:["path":f.path,"content":"X"]).isError); #expect(try String(contentsOf:f,encoding:.utf8)=="X") }
    @Test("parents") func p() throws { let d=TestFixtures.makeTempDir(prefix:"fw-p"); defer{TestFixtures.cleanupTempDir(d)}; #expect(!FileWriteTool.execute(input:["path":d.appendingPathComponent("a/b/c.txt").path,"content":"deep"]).isError) }
    @Test("missing") func m() { #expect(FileWriteTool.execute(input:["content":"x"]).isError); #expect(FileWriteTool.execute(input:["path":"/tmp/x"]).isError) }
    @Test("blocked") func b() { #expect(FileWriteTool.execute(input:["path":"\(FileManager.default.homeDirectoryForCurrentUser.path)/.ssh/x","content":"x"]).isError) }
}
@Suite("FileListTool") struct FileListToolTests {
    @Test("lists") func l() throws { let d=TestFixtures.makeTempDir(prefix:"fl"); defer{TestFixtures.cleanupTempDir(d)}; try "a".write(to:d.appendingPathComponent("f.txt"),atomically:true,encoding:.utf8); #expect(FileListTool.execute(input:["path":d.path]).content.contains("f.txt")) }
    @Test("empty") func e() { let d=TestFixtures.makeTempDir(prefix:"fl-e"); defer{TestFixtures.cleanupTempDir(d)}; #expect(FileListTool.execute(input:["path":d.path]).content.contains("empty")) }
    @Test("blocked") func b() { #expect(FileListTool.execute(input:["path":"/etc"]).isError) }
    @Test("depth") func de() throws { let d=TestFixtures.makeTempDir(prefix:"fl-d"); defer{TestFixtures.cleanupTempDir(d)}; try FileManager.default.createDirectory(at:d.appendingPathComponent("a/b/c"),withIntermediateDirectories:true); try "x".write(to:d.appendingPathComponent("a/b/c/deep.txt"),atomically:true,encoding:.utf8); #expect(!FileListTool.execute(input:["path":d.path,"depth":1]).content.contains("deep.txt")) }
}
