import Testing; import Foundation; @testable import Shellmate

@Suite("FileReadTool") struct FileReadToolTests {
    @Test("instance reads file") func instanceRead() async throws {
        let d = TestFixtures.makeTempDir(prefix: "fr-inst")
        defer { TestFixtures.cleanupTempDir(d) }
        let f = d.appendingPathComponent("inst.txt")
        try "Hello".write(to: f, atomically: true, encoding: .utf8)
        let result = try await FileReadTool().execute(parameters: ["path": f.path])
        #expect(!result.isError)
        #expect(result.content == "Hello")
    }

    @Test("instance missing param") func instanceMissing() async throws {
        let result = try await FileReadTool().execute(parameters: [:])
        #expect(result.isError)
    }

    @Test("instance blocked path") func instanceBlocked() async throws {
        let result = try await FileReadTool().execute(parameters: ["path": "\(FileManager.default.homeDirectoryForCurrentUser.path)/.ssh/id_rsa"])
        #expect(result.isError)
    }

    @Test("instance nonexistent") func instanceNonexistent() async throws {
        let result = try await FileReadTool().execute(parameters: ["path": "/tmp/ne_\(UUID())"])
        #expect(result.isError)
    }

    @Test("instance oversize") func instanceOversize() async throws {
        let d = TestFixtures.makeTempDir(prefix: "fr-s")
        defer { TestFixtures.cleanupTempDir(d) }
        try Data(repeating: 65, count: 3 * 1024 * 1024).write(to: d.appendingPathComponent("big"))
        let result = try await FileReadTool().execute(parameters: ["path": d.appendingPathComponent("big").path])
        #expect(result.isError)
    }

    @Test("protocol properties") func props() {
        let tool = FileReadTool()
        #expect(tool.identifier == "file_read")
        #expect(tool.category == .files)
        #expect(tool.actionTier == .read)
        #expect(tool.parameterSchema.required == ["path"])
    }
}

@Suite("FileWriteTool") struct FileWriteToolTests {
    @Test("instance writes file") func instanceWrite() async throws {
        let d = TestFixtures.makeTempDir(prefix: "fw-inst")
        defer { TestFixtures.cleanupTempDir(d) }
        let f = d.appendingPathComponent("inst.txt")
        let result = try await FileWriteTool().execute(parameters: ["path": f.path, "content": "Written"])
        #expect(!result.isError)
        #expect(try String(contentsOf: f, encoding: .utf8) == "Written")
    }

    @Test("instance creates parent dirs") func instanceParents() async throws {
        let d = TestFixtures.makeTempDir(prefix: "fw-p")
        defer { TestFixtures.cleanupTempDir(d) }
        let result = try await FileWriteTool().execute(parameters: ["path": d.appendingPathComponent("a/b/c.txt").path, "content": "deep"])
        #expect(!result.isError)
    }

    @Test("instance missing params") func instanceMissing() async throws {
        #expect((try await FileWriteTool().execute(parameters: ["content": "x"])).isError)
        #expect((try await FileWriteTool().execute(parameters: ["path": "/tmp/x"])).isError)
    }

    @Test("instance blocked path") func instanceBlocked() async throws {
        let result = try await FileWriteTool().execute(parameters: ["path": "\(FileManager.default.homeDirectoryForCurrentUser.path)/.ssh/x", "content": "x"])
        #expect(result.isError)
    }

    @Test("instance confirmation description") func instanceConfirm() {
        let tool = FileWriteTool()
        let desc = tool.confirmationDescription(parameters: ["path": "/tmp/test.txt"])
        #expect(desc.contains("/tmp/test.txt"))
    }

    @Test("protocol properties") func props() {
        let tool = FileWriteTool()
        #expect(tool.identifier == "file_write")
        #expect(tool.category == .files)
        #expect(tool.actionTier == .write)
        #expect(tool.parameterSchema.required == ["path", "content"])
    }
}

@Suite("FileListTool") struct FileListToolTests {
    @Test("instance lists directory") func instanceList() async throws {
        let d = TestFixtures.makeTempDir(prefix: "fl-inst")
        defer { TestFixtures.cleanupTempDir(d) }
        try "content".write(to: d.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)
        let result = try await FileListTool().execute(parameters: ["path": d.path])
        #expect(!result.isError)
        #expect(result.content.contains("file.txt"))
    }

    @Test("instance empty dir") func instanceEmpty() async throws {
        let d = TestFixtures.makeTempDir(prefix: "fl-e")
        defer { TestFixtures.cleanupTempDir(d) }
        let result = try await FileListTool().execute(parameters: ["path": d.path])
        #expect(result.content.contains("empty"))
    }

    @Test("instance blocked path") func instanceBlocked() async throws {
        let result = try await FileListTool().execute(parameters: ["path": "/etc"])
        #expect(result.isError)
    }

    @Test("instance depth limiting") func instanceDepth() async throws {
        let d = TestFixtures.makeTempDir(prefix: "fl-d")
        defer { TestFixtures.cleanupTempDir(d) }
        try FileManager.default.createDirectory(at: d.appendingPathComponent("a/b/c"), withIntermediateDirectories: true)
        try "x".write(to: d.appendingPathComponent("a/b/c/deep.txt"), atomically: true, encoding: .utf8)
        let result = try await FileListTool().execute(parameters: ["path": d.path, "depth": 1])
        #expect(!result.content.contains("deep.txt"))
    }

    @Test("protocol properties") func props() {
        let tool = FileListTool()
        #expect(tool.identifier == "file_list")
        #expect(tool.category == .files)
        #expect(tool.actionTier == .read)
    }
}

// MARK: - FilesProvider

@Suite("FilesProvider") struct FilesProviderTests {
    @Test("provides all file tools") func allTools() {
        let provider = FilesProvider()
        #expect(provider.category == .files)
        #expect(provider.displayName == "Files & Storage")
        let ids = provider.tools.map(\.identifier)
        #expect(ids.contains("file_read"))
        #expect(ids.contains("file_write"))
        #expect(ids.contains("file_list"))
        #expect(ids.count == 3)
    }
}
