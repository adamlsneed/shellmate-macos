import SwiftUI

/// Helpers for rendering markdown in chat messages.
enum MarkdownRenderer {
    /// Parse a markdown string into an AttributedString for SwiftUI Text views.
    static func render(_ markdown: String) -> AttributedString {
        do {
            let result = try AttributedString(markdown: markdown, options: .init(
                allowsExtendedAttributes: true,
                interpretedSyntax: .inlineOnlyPreservingWhitespace
            ))
            return result
        } catch {
            // Fallback: return plain text
            return AttributedString(markdown)
        }
    }
}
