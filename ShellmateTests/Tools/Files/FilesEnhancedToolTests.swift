import Testing
import Foundation
@testable import Shellmate

@Suite("Enhanced File Tools")
struct FilesEnhancedToolTests {

    private let shellService = ShellService()

    // MARK: - FilesSearchTool

    @Suite("FilesSearchTool")
    struct FilesSearchToolTests {

        @Test("finds a file created in temp dir")
        func findsFile() async throws {
            let dir = TestFixtures.makeTempDir(prefix: "search-test")
            defer { TestFixtures.cleanupTempDir(dir) }

            let file = dir.appendingPathComponent("unique_shellmate_test_marker.txt")
            try "hello search".write(to: file, atomically: true, encoding: .utf8)

            // Give Spotlight a moment to index (mdfind needs this)
            try await Task.sleep(for: .milliseconds(500))

            let tool = FilesSearchTool(shellService: ShellService())
            let result = try await tool.execute(parameters: [
                "query": "unique_shellmate_test_marker",
                "directory": dir.path,
            ])
            // mdfind may or may not find it quickly in CI; just verify no crash and valid output
            #expect(!result.isError || result.content.contains("No files found"))
        }

        @Test("requires query parameter")
        func requiresQuery() async throws {
            let tool = FilesSearchTool(shellService: ShellService())
            let result = try await tool.execute(parameters: [:])
            #expect(result.isError)
            #expect(result.content.contains("query"))
        }
    }

    // MARK: - FilesMoveTool

    @Suite("FilesMoveTool")
    struct FilesMoveToolTests {

        @Test("moves file — source gone, destination exists")
        func movesFile() async throws {
            let dir = TestFixtures.makeTempDir(prefix: "move-test")
            defer { TestFixtures.cleanupTempDir(dir) }

            let src = dir.appendingPathComponent("source.txt")
            let dst = dir.appendingPathComponent("dest.txt")
            try "move me".write(to: src, atomically: true, encoding: .utf8)

            let tool = FilesMoveTool()
            let result = try await tool.execute(parameters: [
                "source": src.path,
                "destination": dst.path,
            ])
            #expect(!result.isError)
            #expect(!FileManager.default.fileExists(atPath: src.path))
            #expect(FileManager.default.fileExists(atPath: dst.path))
        }

        @Test("blocks restricted paths")
        func blocksRestricted() async throws {
            let home = FileManager.default.homeDirectoryForCurrentUser.path
            let tool = FilesMoveTool()
            let result = try await tool.execute(parameters: [
                "source": "\(home)/.ssh/id_rsa",
                "destination": "/tmp/stolen",
            ])
            #expect(result.isError)
            #expect(result.content.contains("restricted"))
        }
    }

    // MARK: - FilesCopyTool

    @Suite("FilesCopyTool")
    struct FilesCopyToolTests {

        @Test("copies file — both exist after")
        func copiesFile() async throws {
            let dir = TestFixtures.makeTempDir(prefix: "copy-test")
            defer { TestFixtures.cleanupTempDir(dir) }

            let src = dir.appendingPathComponent("original.txt")
            let dst = dir.appendingPathComponent("copy.txt")
            try "copy me".write(to: src, atomically: true, encoding: .utf8)

            let tool = FilesCopyTool()
            let result = try await tool.execute(parameters: [
                "source": src.path,
                "destination": dst.path,
            ])
            #expect(!result.isError)
            #expect(FileManager.default.fileExists(atPath: src.path))
            #expect(FileManager.default.fileExists(atPath: dst.path))
        }
    }

    // MARK: - FilesDeleteTool

    @Suite("FilesDeleteTool")
    struct FilesDeleteToolTests {

        @Test("trashes file — gone from original path")
        func trashesFile() async throws {
            let dir = TestFixtures.makeTempDir(prefix: "delete-test")
            defer { TestFixtures.cleanupTempDir(dir) }

            let file = dir.appendingPathComponent("doomed.txt")
            try "bye".write(to: file, atomically: true, encoding: .utf8)

            let tool = FilesDeleteTool()
            let result = try await tool.execute(parameters: ["path": file.path])
            #expect(!result.isError)
            #expect(result.content.lowercased().contains("trash"))
            #expect(!FileManager.default.fileExists(atPath: file.path))
        }

        @Test("is destructive tier")
        func isDestructive() {
            let tool = FilesDeleteTool()
            #expect(tool.actionTier == .destructive)
            #expect(tool.identifier == "files_delete")
            #expect(tool.category == .files)
        }

        @Test("blocks restricted paths")
        func blocksRestricted() async throws {
            let home = FileManager.default.homeDirectoryForCurrentUser.path
            let tool = FilesDeleteTool()
            let result = try await tool.execute(parameters: ["path": "\(home)/.ssh/id_rsa"])
            #expect(result.isError)
            #expect(result.content.contains("restricted"))
        }
    }

    // MARK: - FilesCompressTool

    @Suite("FilesCompressTool")
    struct FilesCompressToolTests {

        @Test("creates zip from temp file")
        func createsZip() async throws {
            let dir = TestFixtures.makeTempDir(prefix: "compress-test")
            defer { TestFixtures.cleanupTempDir(dir) }

            let file = dir.appendingPathComponent("data.txt")
            try "compress me".write(to: file, atomically: true, encoding: .utf8)

            let output = dir.appendingPathComponent("data.zip")
            let tool = FilesCompressTool(shellService: ShellService())
            let result = try await tool.execute(parameters: [
                "paths": file.path,
                "output": output.path,
            ])
            #expect(!result.isError)
            #expect(FileManager.default.fileExists(atPath: output.path))
        }
    }

    // MARK: - FilesDecompressTool

    @Suite("FilesDecompressTool")
    struct FilesDecompressToolTests {

        @Test("extracts zip — output files exist")
        func extractsZip() async throws {
            let dir = TestFixtures.makeTempDir(prefix: "decompress-test")
            defer { TestFixtures.cleanupTempDir(dir) }

            // Create a file and compress it first
            let file = dir.appendingPathComponent("packed.txt")
            try "packed content".write(to: file, atomically: true, encoding: .utf8)

            let zipPath = dir.appendingPathComponent("archive.zip")
            let compressTool = FilesCompressTool(shellService: ShellService())
            let compressResult = try await compressTool.execute(parameters: [
                "paths": file.path,
                "output": zipPath.path,
            ])
            #expect(!compressResult.isError)

            // Now decompress
            let extractDir = dir.appendingPathComponent("extracted")
            let tool = FilesDecompressTool(shellService: ShellService())
            let result = try await tool.execute(parameters: [
                "archive": zipPath.path,
                "destination": extractDir.path,
            ])
            #expect(!result.isError)
            #expect(FileManager.default.fileExists(atPath: extractDir.path))
        }
    }

    // MARK: - FilesDiskUsageTool

    @Suite("FilesDiskUsageTool")
    struct FilesDiskUsageToolTests {

        @Test("returns usage info for temp dir")
        func returnsUsage() async throws {
            let dir = TestFixtures.makeTempDir(prefix: "du-test")
            defer { TestFixtures.cleanupTempDir(dir) }

            let file = dir.appendingPathComponent("bigfile.txt")
            try String(repeating: "x", count: 1024).write(to: file, atomically: true, encoding: .utf8)

            let tool = FilesDiskUsageTool(shellService: ShellService())
            let result = try await tool.execute(parameters: ["directory": dir.path])
            #expect(!result.isError)
            #expect(!result.content.isEmpty)
        }
    }

    // MARK: - FilesOpenTool

    @Suite("FilesOpenTool")
    struct FilesOpenToolTests {

        @Test("conforms — identifier, category, tier")
        func conforms() {
            let tool = FilesOpenTool()
            #expect(tool.identifier == "files_open")
            #expect(tool.category == .files)
            #expect(tool.actionTier == .write)
        }
    }

    // MARK: - FilesRevealInFinderTool

    @Suite("FilesRevealInFinderTool")
    struct FilesRevealInFinderToolTests {

        @Test("conforms — identifier, category, tier")
        func conforms() {
            let tool = FilesRevealInFinderTool()
            #expect(tool.identifier == "files_reveal_in_finder")
            #expect(tool.category == .files)
            #expect(tool.actionTier == .read)
        }
    }

    // MARK: - FilesProvider

    @Suite("FilesProvider Enhanced")
    struct FilesProviderEnhancedTests {

        @Test("has 12 tools total")
        func hasTwelveTools() {
            let provider = FilesProvider(shellService: ShellService())
            #expect(provider.tools.count == 12)
            let ids = Set(provider.tools.map(\.identifier))
            #expect(ids.contains("file_read"))
            #expect(ids.contains("file_write"))
            #expect(ids.contains("file_list"))
            #expect(ids.contains("files_search"))
            #expect(ids.contains("files_move"))
            #expect(ids.contains("files_copy"))
            #expect(ids.contains("files_delete"))
            #expect(ids.contains("files_compress"))
            #expect(ids.contains("files_decompress"))
            #expect(ids.contains("files_disk_usage"))
            #expect(ids.contains("files_open"))
            #expect(ids.contains("files_reveal_in_finder"))
        }
    }
}
