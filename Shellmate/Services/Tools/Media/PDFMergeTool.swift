import Foundation
import PDFKit

/// Merges multiple PDF files into one using PDFKit.
struct PDFMergeTool: AgentTool {
    let identifier = "pdf_merge"
    let toolDescription = "Merge multiple PDF files into a single PDF."
    let category = ToolCategory.media
    let actionTier = ActionTier.write
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "paths": ToolProperty(
                type: "string",
                description: "Comma-separated list of PDF file paths to merge, in order."
            ),
            "output": ToolProperty(
                type: "string",
                description: "Output path for the merged PDF."
            ),
        ],
        required: ["paths", "output"]
    )

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        guard let pathsString = parameters["paths"] as? String else {
            return .error("Missing required parameter: paths")
        }
        guard let output = parameters["output"] as? String else {
            return .error("Missing required parameter: output")
        }

        let paths = pathsString.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }

        guard paths.count >= 2 else {
            return .error("At least 2 PDF files are required to merge.")
        }

        if SecurityPolicy.isPathBlocked(output) {
            return .error("Access denied: output path is restricted")
        }

        let merged = PDFDocument()
        var totalPages = 0

        for path in paths {
            if SecurityPolicy.isPathBlocked(path) {
                return .error("Access denied: input path is restricted (\(path))")
            }
            guard FileManager.default.fileExists(atPath: path) else {
                return .error("File not found: \(path)")
            }
            guard let doc = PDFDocument(url: URL(fileURLWithPath: path)) else {
                return .error("Could not open PDF: \(path)")
            }
            for i in 0..<doc.pageCount {
                if let page = doc.page(at: i) {
                    merged.insert(page, at: totalPages)
                    totalPages += 1
                }
            }
        }

        let outputURL = URL(fileURLWithPath: output)
        guard merged.write(to: outputURL) else {
            return .error("Failed to write merged PDF to: \(output)")
        }

        return .success("Merged \(paths.count) PDFs (\(totalPages) pages) to: \(output)")
    }

    func confirmationDescription(parameters: [String: Any]) -> String {
        let output = parameters["output"] as? String ?? "merged.pdf"
        return "Merge PDFs to: \(output)"
    }
}
