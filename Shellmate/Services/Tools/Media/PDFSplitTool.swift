import Foundation
import PDFKit

/// Splits a PDF by extracting a range of pages into a new file.
struct PDFSplitTool: AgentTool {
    let identifier = "pdf_split"
    let toolDescription = "Extract a range of pages from a PDF into a new PDF file."
    let category = ToolCategory.media
    let actionTier = ActionTier.write
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "path": ToolProperty(
                type: "string",
                description: "Path to the source PDF file."
            ),
            "start_page": ToolProperty(
                type: "integer",
                description: "First page to extract (1-based)."
            ),
            "end_page": ToolProperty(
                type: "integer",
                description: "Last page to extract (1-based)."
            ),
            "output": ToolProperty(
                type: "string",
                description: "Output path for the new PDF."
            ),
        ],
        required: ["path", "start_page", "end_page", "output"]
    )

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        guard let path = parameters["path"] as? String else {
            return .error("Missing required parameter: path")
        }
        guard let output = parameters["output"] as? String else {
            return .error("Missing required parameter: output")
        }

        let startPage: Int
        if let s = parameters["start_page"] as? Int { startPage = s }
        else if let s = parameters["start_page"] as? Double { startPage = Int(s) }
        else { return .error("Missing required parameter: start_page") }

        let endPage: Int
        if let e = parameters["end_page"] as? Int { endPage = e }
        else if let e = parameters["end_page"] as? Double { endPage = Int(e) }
        else { return .error("Missing required parameter: end_page") }

        if SecurityPolicy.isPathBlocked(path) {
            return .error("Access denied: input path is restricted")
        }
        if SecurityPolicy.isPathBlocked(output) {
            return .error("Access denied: output path is restricted")
        }

        guard FileManager.default.fileExists(atPath: path) else {
            return .error("File not found: \(path)")
        }

        guard let document = PDFDocument(url: URL(fileURLWithPath: path)) else {
            return .error("Could not open PDF: \(path)")
        }

        let pageCount = document.pageCount
        guard startPage >= 1, endPage <= pageCount, startPage <= endPage else {
            return .error("Invalid page range \(startPage)-\(endPage). PDF has \(pageCount) pages.")
        }

        let newDoc = PDFDocument()
        for i in (startPage - 1)..<endPage {
            if let page = document.page(at: i) {
                newDoc.insert(page, at: newDoc.pageCount)
            }
        }

        let outputURL = URL(fileURLWithPath: output)
        guard newDoc.write(to: outputURL) else {
            return .error("Failed to write PDF to: \(output)")
        }

        let extractedCount = endPage - startPage + 1
        return .success("Extracted pages \(startPage)-\(endPage) (\(extractedCount) pages) to: \(output)")
    }

    func confirmationDescription(parameters: [String: Any]) -> String {
        let start = parameters["start_page"] as? Int ?? 0
        let end = parameters["end_page"] as? Int ?? 0
        let output = parameters["output"] as? String ?? "output.pdf"
        return "Extract pages \(start)-\(end) to: \(output)"
    }
}
