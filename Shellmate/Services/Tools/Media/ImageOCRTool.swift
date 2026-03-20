import Foundation
import Vision
import AppKit

/// Extracts text from an image using the Vision framework.
struct ImageOCRTool: AgentTool {
    let identifier = "image_ocr"
    let toolDescription = "Extract text from an image using OCR (optical character recognition)."
    let category = ToolCategory.media
    let actionTier = ActionTier.read
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "path": ToolProperty(
                type: "string",
                description: "Path to the image file to extract text from."
            ),
        ],
        required: ["path"]
    )

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        guard let path = parameters["path"] as? String else {
            return .error("Missing required parameter: path")
        }

        guard FileManager.default.fileExists(atPath: path) else {
            return .error("File not found: \(path)")
        }

        let url = URL(fileURLWithPath: path)
        guard let image = NSImage(contentsOf: url),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return .error("Could not load image from: \(path)")
        }

        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(returning: .error("OCR failed: \(error.localizedDescription)"))
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: .success("No text found in image."))
                    return
                }

                let text = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }.joined(separator: "\n")

                if text.isEmpty {
                    continuation.resume(returning: .success("No text found in image."))
                } else {
                    continuation.resume(returning: .success(text))
                }
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: .error("OCR processing failed: \(error.localizedDescription)"))
            }
        }
    }
}
