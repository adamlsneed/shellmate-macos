import Testing
import Foundation
@testable import Shellmate

@Suite("MediaProvider Tools")
struct MediaToolTests {

    private static let shell = ShellService()
    private static let appleScript = AppleScriptService(shellService: shell)

    // MARK: - MusicSearchTool

    @Suite("MusicSearchTool")
    struct MusicSearchToolTests {

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = MusicSearchTool(appleScriptService: appleScript)
            #expect(tool.identifier == "music_search")
            #expect(tool.category == .media)
            #expect(tool.actionTier == .read)
        }

        @Test("requires query parameter")
        func requiresQuery() async throws {
            let tool = MusicSearchTool(appleScriptService: appleScript)
            let result = try await tool.execute(parameters: [:])
            #expect(result.isError)
            #expect(result.content.contains("query"))
        }
    }

    // MARK: - MusicPlayTool

    @Suite("MusicPlayTool")
    struct MusicPlayToolTests {

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = MusicPlayTool(appleScriptService: appleScript)
            #expect(tool.identifier == "music_play")
            #expect(tool.category == .media)
            #expect(tool.actionTier == .write)
        }

        @Test("provides confirmation description")
        func confirmationDescription() {
            let tool = MusicPlayTool(appleScriptService: appleScript)
            let desc = tool.confirmationDescription(parameters: ["track": "Bohemian Rhapsody"])
            #expect(desc.contains("Bohemian Rhapsody"))
        }
    }

    // MARK: - MusicQueueTool

    @Suite("MusicQueueTool")
    struct MusicQueueToolTests {

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = MusicQueueTool(appleScriptService: appleScript)
            #expect(tool.identifier == "music_queue")
            #expect(tool.category == .media)
            #expect(tool.actionTier == .read)
        }
    }

    // MARK: - ScreenshotCaptureTool

    @Suite("ScreenshotCaptureTool")
    struct ScreenshotCaptureToolTests {

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = ScreenshotCaptureTool(shellService: shell)
            #expect(tool.identifier == "screenshot_capture")
            #expect(tool.category == .media)
            #expect(tool.actionTier == .write)
        }

        @Test("provides confirmation description")
        func confirmationDescription() {
            let tool = ScreenshotCaptureTool(shellService: shell)
            let desc = tool.confirmationDescription(parameters: ["area": "window"])
            #expect(desc.contains("window"))
        }
    }

    // MARK: - ImageResizeTool

    @Suite("ImageResizeTool")
    struct ImageResizeToolTests {

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = ImageResizeTool(shellService: shell)
            #expect(tool.identifier == "image_resize")
            #expect(tool.category == .media)
            #expect(tool.actionTier == .write)
        }

        @Test("requires path parameter")
        func requiresPath() async throws {
            let tool = ImageResizeTool(shellService: shell)
            let result = try await tool.execute(parameters: ["width": 100])
            #expect(result.isError)
            #expect(result.content.contains("path"))
        }

        @Test("requires at least width or height")
        func requiresDimension() async throws {
            let tool = ImageResizeTool(shellService: shell)
            let result = try await tool.execute(parameters: ["path": "/tmp/nonexistent.png"])
            #expect(result.isError)
        }
    }

    // MARK: - ImageConvertTool

    @Suite("ImageConvertTool")
    struct ImageConvertToolTests {

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = ImageConvertTool(shellService: shell)
            #expect(tool.identifier == "image_convert")
            #expect(tool.category == .media)
            #expect(tool.actionTier == .write)
        }

        @Test("requires path parameter")
        func requiresPath() async throws {
            let tool = ImageConvertTool(shellService: shell)
            let result = try await tool.execute(parameters: ["format": "png"])
            #expect(result.isError)
            #expect(result.content.contains("path"))
        }

        @Test("requires format parameter")
        func requiresFormat() async throws {
            let tool = ImageConvertTool(shellService: shell)
            let result = try await tool.execute(parameters: ["path": "/tmp/test.jpg"])
            #expect(result.isError)
            #expect(result.content.contains("format"))
        }

        @Test("rejects invalid format")
        func rejectsInvalidFormat() async throws {
            let tool = ImageConvertTool(shellService: shell)
            // Create a temp file so the file check passes
            let path = NSTemporaryDirectory() + "test_convert.jpg"
            FileManager.default.createFile(atPath: path, contents: Data())
            defer { try? FileManager.default.removeItem(atPath: path) }

            let result = try await tool.execute(parameters: ["path": path, "format": "webp"])
            #expect(result.isError)
            #expect(result.content.contains("Invalid format"))
        }
    }

    // MARK: - ImageOCRTool

    @Suite("ImageOCRTool")
    struct ImageOCRToolTests {

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = ImageOCRTool()
            #expect(tool.identifier == "image_ocr")
            #expect(tool.category == .media)
            #expect(tool.actionTier == .read)
        }

        @Test("requires path parameter")
        func requiresPath() async throws {
            let tool = ImageOCRTool()
            let result = try await tool.execute(parameters: [:])
            #expect(result.isError)
            #expect(result.content.contains("path"))
        }

        @Test("returns error for nonexistent file")
        func nonexistentFile() async throws {
            let tool = ImageOCRTool()
            let result = try await tool.execute(parameters: ["path": "/tmp/nonexistent_ocr_test.png"])
            #expect(result.isError)
            #expect(result.content.contains("not found"))
        }
    }

    // MARK: - PDFReadTool

    @Suite("PDFReadTool")
    struct PDFReadToolTests {

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = PDFReadTool()
            #expect(tool.identifier == "pdf_read")
            #expect(tool.category == .media)
            #expect(tool.actionTier == .read)
        }

        @Test("requires path parameter")
        func requiresPath() async throws {
            let tool = PDFReadTool()
            let result = try await tool.execute(parameters: [:])
            #expect(result.isError)
            #expect(result.content.contains("path"))
        }

        @Test("returns error for nonexistent file")
        func nonexistentFile() async throws {
            let tool = PDFReadTool()
            let result = try await tool.execute(parameters: ["path": "/tmp/nonexistent_test.pdf"])
            #expect(result.isError)
            #expect(result.content.contains("not found"))
        }
    }

    // MARK: - PDFMergeTool

    @Suite("PDFMergeTool")
    struct PDFMergeToolTests {

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = PDFMergeTool()
            #expect(tool.identifier == "pdf_merge")
            #expect(tool.category == .media)
            #expect(tool.actionTier == .write)
        }

        @Test("requires paths parameter")
        func requiresPaths() async throws {
            let tool = PDFMergeTool()
            let result = try await tool.execute(parameters: ["output": "/tmp/merged.pdf"])
            #expect(result.isError)
            #expect(result.content.contains("paths"))
        }

        @Test("requires at least 2 files")
        func requiresMultipleFiles() async throws {
            let tool = PDFMergeTool()
            let result = try await tool.execute(parameters: ["paths": "/tmp/one.pdf", "output": "/tmp/merged.pdf"])
            #expect(result.isError)
            #expect(result.content.contains("2"))
        }
    }

    // MARK: - PDFSplitTool

    @Suite("PDFSplitTool")
    struct PDFSplitToolTests {

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = PDFSplitTool()
            #expect(tool.identifier == "pdf_split")
            #expect(tool.category == .media)
            #expect(tool.actionTier == .write)
        }

        @Test("requires path parameter")
        func requiresPath() async throws {
            let tool = PDFSplitTool()
            let result = try await tool.execute(parameters: ["start_page": 1, "end_page": 2, "output": "/tmp/split.pdf"])
            #expect(result.isError)
            #expect(result.content.contains("path"))
        }
    }

    // MARK: - MediaProvider

    @Suite("MediaProvider")
    struct MediaProviderTests {

        @Test("provider has correct category and tool count")
        func providerMetadata() {
            let provider = MediaProvider(shellService: shell, appleScriptService: appleScript)
            #expect(provider.category == .media)
            #expect(provider.displayName == "Media")
            #expect(provider.tools.count == 10)
        }

        @Test("provider contains all expected tool identifiers")
        func providerToolIdentifiers() {
            let provider = MediaProvider(shellService: shell, appleScriptService: appleScript)
            let ids = Set(provider.tools.map(\.identifier))
            #expect(ids.contains("music_search"))
            #expect(ids.contains("music_play"))
            #expect(ids.contains("music_queue"))
            #expect(ids.contains("screenshot_capture"))
            #expect(ids.contains("image_resize"))
            #expect(ids.contains("image_convert"))
            #expect(ids.contains("image_ocr"))
            #expect(ids.contains("pdf_read"))
            #expect(ids.contains("pdf_merge"))
            #expect(ids.contains("pdf_split"))
        }

        @Test("provider requires appleEvents and screenCapture permissions")
        func providerPermissions() {
            let provider = MediaProvider(shellService: shell, appleScriptService: appleScript)
            #expect(provider.requiredPermissions.contains(.appleEvents))
            #expect(provider.requiredPermissions.contains(.screenCapture))
        }
    }
}
