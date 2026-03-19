import Testing; import Foundation; @testable import Shellmate
@Suite("WorkspaceService") struct WorkspaceServiceTests {
    @Test("path") func p() { let s=WorkspaceService(); #expect(s.workspacePath.lastPathComponent=="workspace"); #expect(s.workspacePath.path.contains(".shellmate")) }
    @Test("fileExists false") func fe() { #expect(!WorkspaceService().fileExists(name:"NE_\(UUID()).md")) }
    @Test("listFiles") func lf() { _ = WorkspaceService().listFiles() }
}
