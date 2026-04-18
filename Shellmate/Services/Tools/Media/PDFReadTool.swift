import Foundation
import PDFKit

/// Extracts text from a PDF document using PDFKit.
struct PDFReadTool: AgentTool {
    let identifier = "pdf_read"
    let toolDescription = "Extract text content from a PDF file. Optionally specify a page range."
    let category = ToolCategory.media
    let actionTier = ActionTier.read
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "path": ToolProperty(
                type: "string",
                description: "Path to the PDF file."
            ),
            "start_page": ToolProperty(
                type: "integer",
                description: "First page to read (1-based). Defaults to 1."
            ),
            "end_page": ToolProperty(
                type: "integer",
                description: "Last page to read (1-based). Defaults to last page."
            ),
        ],
        required: ["path"]
    )

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        guard let path = parameters["path"] as? String else {
            return .error("Missing required parameter: path")
        }

        if SecurityPolicy.isPathBlocked(path) {
            return .error("Access denied: path is restricted")
        }

        guard FileManager.default.fileExists(atPath: path) else {
            return .error("File not found: \(path)")
        }

        let url = URL(fileURLWithPath: path)
        guard let document = PDFDocument(url: url) else {
            return .error("Could not open PDF: \(path)")
        }

        let pageCount = document.pageCount
        let startPage = max(1, (parameters["start_page"] as? Int) ?? (parameters["start_page"] as? Double).map { Int($0) } ?? 1)
        let endPage = min(pageCount, (parameters["end_page"] as? Int) ?? (parameters["end_page"] as? Double).map { Int($0) } ?? pageCount)

        guard startPage <= endPage else {
            return .error("start_page (\(startPage)) must be <= end_page (\(endPage))")
        }

        var text = ""
        for i in (startPage - 1)..<endPage {
            if let page = document.page(at: i), let pageText = page.string {
                text += "--- Page \(i + 1) ---\n\(pageText)\n\n"
            }
        }

        if text.isEmpty {
            return .success("No text content found in PDF (pages \(startPage)-\(endPage) of \(pageCount)).")
        }

        // Truncate if very large
        if text.count > 50_000 {
            text = String(text.prefix(50_000)) + "\n... [truncated at 50000 chars]"
        }

        return .success("PDF: \(pageCount) pages total, showing \(startPage)-\(endPage):\n\n\(text)")
    }
}
